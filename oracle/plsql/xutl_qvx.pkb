create or replace package body xutl_qvx is
/* ======================================================================================

  MIT License

  Copyright (c) 2019-2020 Marc Bleron

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

=========================================================================================
    Change history :
    Marc Bleron       2019-12-01     Creation
====================================================================================== */

  OA_ZERO_DATE                   constant date := date '1899-12-30';
  OA_ZERO_TIMESTAMP              constant timestamp := timestamp '1899-12-30 00:00:00';
  
  P2_64                          constant integer := 18446744073709551616;
  BYTE_ZERO                      constant raw(1) := '00';
  FL_NOT_NULL                    constant raw(1) := BYTE_ZERO;
  FL_NULL                        constant raw(1) := '01';
  
  BUFFER_SIZE                    constant pls_integer := 768;
  CHUNK_SIZE                     constant pls_integer := 8191;

  -- QvxFieldType
  QVX_SIGNED_INTEGER             constant pls_integer := 1;
  QVX_UNSIGNED_INTEGER           constant pls_integer := 2;
  QVX_IEEE_REAL                  constant pls_integer := 3;
  QVX_PACKED_BCD                 constant pls_integer := 4;
  QVX_BLOB                       constant pls_integer := 5;
  QVX_TEXT                       constant pls_integer := 6;
  QVX_QV_DUAL                    constant pls_integer := 7;
  -- QvxFieldExtent
  QVX_FIX                        constant pls_integer := 8;
  QVX_COUNTED                    constant pls_integer := 9;
  QVX_ZERO_TERMINATED            constant pls_integer := 10;
  QVX_QV_SPECIAL                 constant pls_integer := 11;
  -- QvxNullRepresentation
  QVX_NULL_NEVER                 constant pls_integer := 12;
  QVX_NULL_ZERO_LENGTH           constant pls_integer := 13;
  QVX_NULL_FLAG_WITH_UNDEF_DATA  constant pls_integer := 14;
  QVX_NULL_FLAG_SUPPRESS_DATA    constant pls_integer := 15;
  -- FieldAttrType
  T_UNKNOWN                      constant pls_integer := 16;
  T_ASCII                        constant pls_integer := 17;
  T_INTEGER                      constant pls_integer := 18;
  T_REAL                         constant pls_integer := 19;
  T_FIX                          constant pls_integer := 20;
  T_MONEY                        constant pls_integer := 21;
  T_DATE                         constant pls_integer := 22;
  T_TIME                         constant pls_integer := 23;
  T_TIMESTAMP                    constant pls_integer := 24;
  T_INTERVAL                     constant pls_integer := 25;

  -- QvxQvSpecialFlag
  QVX_QV_SPECIAL_NULL            constant raw(1) := hextoraw('00');
  QVX_QV_SPECIAL_INT             constant raw(1) := hextoraw('01');
  QVX_QV_SPECIAL_DOUBLE          constant raw(1) := hextoraw('02');
  QVX_QV_SPECIAL_STRING          constant raw(1) := hextoraw('04');
  QVX_QV_SPECIAL_INT_AND_STRING  constant raw(1) := hextoraw('05');
  QVX_QV_SPECIAL_DBL_AND_STRING  constant raw(1) := hextoraw('06');
  
  type ConstantMap_t is table of varchar2(256);
  CONST constant  ConstantMap_t := ConstantMap_t(
    'QVX_SIGNED_INTEGER'
  , 'QVX_UNSIGNED_INTEGER'
  , 'QVX_IEEE_REAL'
  , 'QVX_PACKED_BCD'
  , 'QVX_BLOB'
  , 'QVX_TEXT'
  , 'QVX_QV_DUAL'
  , 'QVX_FIX'
  , 'QVX_COUNTED'
  , 'QVX_ZERO_TERMINATED'
  , 'QVX_QV_SPECIAL'
  , 'QVX_NULL_NEVER'
  , 'QVX_NULL_ZERO_LENGTH'
  , 'QVX_NULL_FLAG_WITH_UNDEFINED_DATA'
  , 'QVX_NULL_FLAG_SUPPRESS_DATA'
  , 'UNKNOWN'
  , 'ASCII'
  , 'INTEGER'
  , 'REAL'
  , 'FIX'
  , 'MONEY'
  , 'DATE'
  , 'TIME'
  , 'TIMESTAMP'
  , 'INTERVAL'
  );
  
  type FieldAttributes_t is record (
    Type     pls_integer
  , nDec     integer
  , UseThou  integer
  , Fmt      varchar2(256)
  , Dec      varchar2(1)
  , Thou     varchar2(1)
  --, extFmt   varchar2(128)
  );

  type QvxFieldHeader_t is record (
    FieldName           varchar2(128)
  , Type                pls_integer
  , Extent              pls_integer
  , NullRepresentation  pls_integer
  , BigEndian           boolean
  , CodePage            integer
  , ByteWidth           integer
  , FixPointDecimals    integer
  , FieldFormat         FieldAttributes_t
  , extColumnType       pls_integer
  , extPowerTen         integer
  );
  
  type QvxFields_t is table of QvxFieldHeader_t;

  type QvxTableHeader_t is record (
    MajorVersion       pls_integer := 1
  , MinorVersion       pls_integer := 0
  , CreateUtcTime      date
  , TableName          varchar2(32767)
  , UsesSeparatorByte  boolean
  , BlockSize          integer
  , Fields             QvxFields_t
  );
  
  type context_t is record (
    cursorNumber  integer
  , executeCursor boolean
  , tableHeader   QvxTableHeader_t
  , output        blob
  , fd            utl_file.file_type
  , nrows         integer
  );
  
  type context_cache_t is table of context_t index by pls_integer;

  type data_t is record (
    varchar2_value  varchar2(32767)
  , char_value      char(32767)
  , number_value    number
  , date_value      date
  , ts_value        timestamp_unconstrained
  , ts_tz_value     timestamp_tz_unconstrained
  , ts_ltz_value    timestamp_ltz_unconstrained
  , clob_value      clob
  , blob_value      blob
  );
  
  ctx_cache    context_cache_t;
  isDebug      boolean := false;
  
  procedure setDebug(
    status in boolean
  )
  is
  begin
    isDebug := status;
  end;
  
  procedure debug(
    message in varchar2
  )
  is
  begin
    if isDebug then
      dbms_output.put_line(message);
    end if;
  end;

  procedure describeCursor(
    ctx  in out nocopy context_t
  )
  is
    data    data_t;
    fields  QvxFields_t := QvxFields_t();
    f       QvxFieldHeader_t;
    
    c  integer := ctx.cursorNumber;
    r  dbms_sql.desc_rec;
    t  dbms_sql.desc_tab;
    n  integer;
    
    procedure p (
      txt in varchar2
    , arg1 in varchar2 default null
    , arg2 in varchar2 default null
    , arg3 in varchar2 default null
    )
    is
    begin
      debug(utl_lms.format_message(txt, arg1, arg2, arg3));
    end;

  begin
    
    dbms_sql.describe_columns(c, n, t);
    
    p('--------------------------');
    for i in 1 .. n loop
      
      f := null;
      r := t(i);
    
      p('col_name=%s', r.col_name);
      p('col_type=%s', r.col_type);
      p('col_null_ok=%s', case when r.col_null_ok then 'true' else 'false' end);
      
      f.FieldName := r.col_name;
      f.NullRepresentation := case when r.col_null_ok then QVX_NULL_FLAG_SUPPRESS_DATA else QVX_NULL_NEVER end;
      f.extColumnType := r.col_type;
      
      if r.col_type in (DBMS_SQL.CHAR_TYPE
                      , DBMS_SQL.VARCHAR2_TYPE
                      , DBMS_SQL.CLOB_TYPE) 
      then
        
        f.Type := QVX_TEXT;
        f.Extent := QVX_ZERO_TERMINATED;
        f.CodePage := 65001; -- UTF-8
        f.FieldFormat.Type := T_ASCII;
        
        case r.col_type
        when DBMS_SQL.VARCHAR2_TYPE then
          dbms_sql.define_column(c, i, data.varchar2_value, r.col_max_len);
        when DBMS_SQL.CHAR_TYPE then
          dbms_sql.define_column_char(c, i, data.char_value, r.col_max_len);
        else -- CLOB
          dbms_sql.define_column(c, i, data.clob_value);
        end case;   
        
      elsif r.col_type = DBMS_SQL.NUMBER_TYPE then
        p('col_precision=%s', r.col_precision);
        p('col_scale=%s', r.col_scale);
        
        f.Extent := QVX_FIX;
        
        if r.col_precision > 0 then
          if r.col_precision < 3 then
            -- int8
            f.Type := QVX_SIGNED_INTEGER;
            f.ByteWidth := 1;
            f.FieldFormat.Type := T_INTEGER;
            if r.col_scale > 0 then
              f.FixPointDecimals := r.col_scale;
              f.FieldFormat.Type := T_REAL;
              f.FieldFormat.nDec := r.col_precision;
            end if;
          elsif r.col_precision < 5 then
            -- int16
            f.Type := QVX_SIGNED_INTEGER;
            f.ByteWidth := 2;
            f.FieldFormat.Type := T_INTEGER;
            if r.col_scale > 0 then
              f.FixPointDecimals := r.col_scale;
              f.FieldFormat.Type := T_REAL;
              f.FieldFormat.nDec := r.col_precision;
            end if;
          elsif r.col_precision < 10 then
            -- int32
            f.Type := QVX_SIGNED_INTEGER;
            f.ByteWidth := 4;
            f.FieldFormat.Type := T_INTEGER;
            if r.col_scale > 0 then
              f.FixPointDecimals := r.col_scale;
              f.FieldFormat.Type := T_REAL;
              f.FieldFormat.nDec := r.col_precision;
            end if;
          elsif r.col_precision < 19 then
            -- int64
            f.Type := QVX_SIGNED_INTEGER;
            f.ByteWidth := 8;
            f.BigEndian := true;
            f.FieldFormat.Type := T_INTEGER;
            if r.col_scale > 0 then
              f.FixPointDecimals := r.col_scale;
              f.FieldFormat.Type := T_REAL;
              f.FieldFormat.nDec := r.col_precision;
            end if;
          else
            f.Type := QVX_IEEE_REAL;
            f.ByteWidth := 8;
            f.FieldFormat.Type := T_REAL;
            --f.FieldFormat.nDec := 15;
          end if;      
        else
          f.Type := QVX_IEEE_REAL;
          f.ByteWidth := 8;
          f.FieldFormat.Type := T_REAL;
          --f.FieldFormat.nDec := 15;
        end if;
        
        f.extPowerTen := 10 ** f.FixPointDecimals;
        
        dbms_sql.define_column(c, i, data.number_value);
        
      elsif r.col_type = DBMS_SQL.DATE_TYPE then
        
        /*
        f.Type := QVX_TEXT;
        f.Extent := QVX_ZERO_TERMINATED;
        f.CodePage := 65001; -- UTF-8
        f.FieldFormat.Type := T_DATE;
        f.FieldFormat.Fmt := 'YYYYMMDDhhmmss';
        f.FieldFormat.extFmt := 'YYYYMMDDHH24MISS';
        */
        f.Type := QVX_IEEE_REAL;
        f.Extent := QVX_FIX;
        f.ByteWidth := 8;
        f.FieldFormat.Type := T_DATE;
        
        dbms_sql.define_column(c, i, data.date_value);
      
      elsif r.col_type in (DBMS_SQL.TIMESTAMP_TYPE
                         , DBMS_SQL.TIMESTAMP_WITH_TZ_TYPE
                         , DBMS_SQL.TIMESTAMP_WITH_LOCAL_TZ_TYPE) 
      then
        p('col_scale=%s', r.col_scale);
        /*
        f.Type := QVX_TEXT;
        f.Extent := QVX_ZERO_TERMINATED;
        f.CodePage := 65001; -- UTF-8
        f.FieldFormat.Type := T_TIMESTAMP;
        f.FieldFormat.Fmt := 'YYYYMMDDhhmmss'||rpad('f',r.col_scale,'f');
        f.FieldFormat.extFmt := 'YYYYMMDDHH24MISS' || case when r.col_scale != 0 then 'FF'||to_char(r.col_scale) end;
        */
        f.Type := QVX_IEEE_REAL;
        f.Extent := QVX_FIX;
        f.ByteWidth := 8;
        f.FieldFormat.Type := T_TIMESTAMP;
        
        case r.col_type
        when DBMS_SQL.TIMESTAMP_TYPE then
          dbms_sql.define_column(c, i, data.ts_value);
        when DBMS_SQL.TIMESTAMP_WITH_TZ_TYPE then
          dbms_sql.define_column(c, i, data.ts_tz_value);
        else -- TIMESTAMP_WITH_LOCAL_TZ
          dbms_sql.define_column(c, i, data.ts_ltz_value);
        end case;
        
      elsif r.col_type = DBMS_SQL.BLOB_TYPE then
        f.Type := QVX_BLOB;
        f.Extent := QVX_COUNTED;
        f.ByteWidth := 8;
        f.BigEndian := true;
        f.FieldFormat.Type := T_UNKNOWN;
        dbms_sql.define_column(c, i, data.blob_value);
      
      end if;
      
      p('--------------------------');
      
      fields.extend;
      fields(fields.last) := f;
      
    end loop;
    
    ctx.cursorNumber := c;
    ctx.tableHeader.fields := fields;

  end;
  
  function getXmlHeader(
    ctx in context_t
  )
  return clob
  is
    doc              dbms_xmldom.DOMDocument;
    rootNode         dbms_xmldom.DOMNode;
    fieldsNode       dbms_xmldom.DOMNode;
    fieldNode        dbms_xmldom.DOMNode;
    fieldFormatNode  dbms_xmldom.DOMNode;
    output           clob;
    
    function createSimpleElement(
      nodeName  in varchar2
    , nodeValue in varchar2 default null
    , ignoreNull  in boolean default true
    )
    return dbms_xmldom.DOMNode
    is
      elemNode  dbms_xmldom.DOMNode;
      textNode  dbms_xmldom.DOMNode;  
    begin
      if not(ignoreNull and nodeValue is null) then
        elemNode := dbms_xmldom.makeNode(dbms_xmldom.createElement(doc, nodeName));
        if nodeValue is not null then
          textNode := dbms_xmldom.makeNode(dbms_xmldom.createTextNode(doc, nodeValue));
          textNode := dbms_xmldom.appendChild(elemNode, textNode);
          dbms_xmldom.freeNode(textNode);
        end if;
      end if;
      return elemNode;
    end;
    
    function createElement(
      nodeName  in varchar2
    )
    return dbms_xmldom.DOMNode
    is 
    begin
      return createSimpleElement(nodeName, ignoreNull => false);
    end;
    
    procedure addSimpleElement (
      parentNode  in dbms_xmldom.DOMNode
    , nodeName    in varchar2
    , nodeValue   in varchar2 default null
    )
    is
      childNode  dbms_xmldom.DOMNode;
    begin
      childNode := createSimpleElement(nodeName, nodeValue);
      if not dbms_xmldom.isNull(childNode) then
        childNode := dbms_xmldom.appendChild(parentNode, childNode);
      end if;
    end;
    
  begin
    doc := dbms_xmldom.newDOMDocument();
    
    rootNode := dbms_xmldom.appendChild(dbms_xmldom.makeNode(doc), createElement('QvxTableHeader'));
    addSimpleElement(rootNode, 'MajorVersion', ctx.tableHeader.MajorVersion);
    addSimpleElement(rootNode, 'MinorVersion', ctx.tableHeader.MinorVersion);
    addSimpleElement(rootNode, 'CreateUtcTime', to_char(ctx.tableHeader.CreateUtcTime, 'YYYY-MM-DD HH24:MI:SS'));
    addSimpleElement(rootNode, 'TableName', ctx.tableHeader.TableName);
    --addSimpleElement(rootNode, 'UsesSeparatorByte', case when header.UsesSeparatorByte then '1' else '0' end);
    --addSimpleElement(rootNode, 'BlockSize', header.BlockSize);
    
    fieldsNode := dbms_xmldom.appendChild(rootNode, createElement('Fields'));
    
    for i in 1 .. ctx.tableHeader.Fields.count loop
      fieldNode := createElement('QvxFieldHeader');
      addSimpleElement(fieldNode, 'FieldName', ctx.tableHeader.Fields(i).FieldName);
      addSimpleElement(fieldNode, 'Type', CONST(ctx.tableHeader.Fields(i).Type));
      addSimpleElement(fieldNode, 'Extent', CONST(ctx.tableHeader.Fields(i).Extent));
      addSimpleElement(fieldNode, 'NullRepresentation', CONST(ctx.tableHeader.Fields(i).NullRepresentation));
      addSimpleElement(fieldNode, 'BigEndian', case when ctx.tableHeader.Fields(i).BigEndian then '1' else '0' end);
      addSimpleElement(fieldNode, 'ByteWidth', ctx.tableHeader.Fields(i).ByteWidth);
      addSimpleElement(fieldNode, 'FixPointDecimals', ctx.tableHeader.Fields(i).FixPointDecimals);
      
      fieldFormatNode := dbms_xmldom.appendChild(fieldNode, createElement('FieldFormat'));
      addSimpleElement(fieldFormatNode, 'Type', CONST(ctx.tableHeader.Fields(i).FieldFormat.Type));
      addSimpleElement(fieldFormatNode, 'nDec', ctx.tableHeader.Fields(i).FieldFormat.nDec);
      addSimpleElement(fieldFormatNode, 'Fmt', ctx.tableHeader.Fields(i).FieldFormat.Fmt);
      
      fieldNode := dbms_xmldom.appendChild(fieldsNode, fieldNode);
    end loop;
       
    dbms_lob.createtemporary(output, true);
    dbms_xmldom.writeToClob(doc, output);
    dbms_xmldom.freeDocument(doc);
    
    return output;
  
  end;

  function int64(n in integer) return raw is
  begin
    if n >= 0 then
      return hextoraw(to_char(n, 'FM0XXXXXXXXXXXXXXX'));
    else
      return hextoraw(to_char(n + P2_64, 'FM0XXXXXXXXXXXXXXX'));
    end if;
  end;
  
  function toOADate(ts in timestamp_unconstrained) return binary_double is
    ids dsinterval_unconstrained := ts - OA_ZERO_TIMESTAMP;
  begin
    return to_binary_double(  
             extract(day from ids) + 
             extract(hour from ids)/24 + 
             extract(minute from ids)/1440 + 
             extract(second from ids)/86400
           );
  end;
  
  procedure writeData(
    ctx  in out nocopy context_t
  )
  is
    xmlHeader    clob;
    data         data_t;
    fields       QvxFields_t := ctx.tableHeader.fields;
    c            integer := ctx.cursorNumber;
    buf          raw(32767);
    sz           pls_integer := 0;
    hasNullFlag  boolean := false;
    result       integer;
    
    procedure putBytes(bytes in raw) is
      len  pls_integer := utl_raw.length(bytes);
    begin
      if sz + len <= BUFFER_SIZE then
        buf := utl_raw.concat(buf, bytes);
        sz := sz + len;
      else
        --dbms_lob.writeappend(ctx.output, sz, buf);
        utl_file.put_raw(ctx.fd, buf);
        buf := bytes;
        sz := len;
      end if;
    end;
    
    procedure putString(str in varchar2, zeroTerminated in boolean default true) is
      len pls_integer := length(str);
    begin
      if str is not null then
        if hasNullFlag then
          putBytes(FL_NOT_NULL);
        end if;
        if len <= CHUNK_SIZE then
          putBytes(utl_i18n.string_to_raw(str, 'AL32UTF8'));
        else
          for i in 0 .. ceil(len/CHUNK_SIZE)-1 loop
            putBytes(utl_i18n.string_to_raw(substr(str, CHUNK_SIZE*i+1, CHUNK_SIZE), 'AL32UTF8'));
          end loop;
        end if;
        -- terminate string
        if zeroTerminated then
          putBytes(BYTE_ZERO);
        end if;
      else
        putBytes(FL_NULL);
      end if;
    end;

    procedure putClob(content in out nocopy clob, zeroTerminated in boolean default true) is
      chunk  varchar2(8191 char);
      amount integer := CHUNK_SIZE;
      offset integer := 1;
      len    integer := dbms_lob.getlength(content);
    begin
      loop
        dbms_lob.read(content, amount, offset, chunk);
        putBytes(utl_i18n.string_to_raw(chunk, 'AL32UTF8'));
        offset := offset + amount;
        exit when offset > len;
      end loop;
      -- terminate string
      if zeroTerminated then
        putBytes(BYTE_ZERO);
      end if;
      if dbms_lob.istemporary(content) = 1 then
        dbms_lob.freetemporary(content);
      end if;
    end;
    
    procedure putBlob(content in blob) is
      amount integer := 32767;
      offset integer := 1;
      len    integer := dbms_lob.getlength(content);
    begin
      -- byte count
      putBytes(int64(len));
      -- flush buffer
      if sz != 0 then
        --dbms_lob.writeappend(ctx.output, sz, buf);
        utl_file.put_raw(ctx.fd, buf);
      end if;
      loop
        dbms_lob.read(content, amount, offset, buf);
        --dbms_lob.writeappend(ctx.output, amount, buf);
        utl_file.put_raw(ctx.fd, buf);
        offset := offset + amount;
        exit when offset > len;
      end loop;
      buf := null;
      sz := 0;
    end;
    
  begin
    
    putString('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'||chr(10), false);
    xmlHeader := getXmlHeader(ctx);
    putClob(xmlHeader, false);
    putBytes(BYTE_ZERO);
    
    if ctx.executeCursor then
      result := dbms_sql.execute(c);
    end if;
    
    ctx.nrows := 0;
    
    loop
      
      result := dbms_sql.fetch_rows(c);
      exit when result = 0;
      
      ctx.nrows := ctx.nrows + 1;
  
      for i in 1 .. fields.count loop
        
        hasNullFlag := (fields(i).NullRepresentation = QVX_NULL_FLAG_SUPPRESS_DATA);
          
        case fields(i).extColumnType
        when DBMS_SQL.VARCHAR2_TYPE then
          dbms_sql.column_value(c, i, data.varchar2_value);
          putString(data.varchar2_value);
              
        when DBMS_SQL.CHAR_TYPE then
          dbms_sql.column_value_char(c, i, data.char_value);
          putString(rtrim(data.char_value));
              
        when DBMS_SQL.NUMBER_TYPE then
          dbms_sql.column_value(c, i, data.number_value);
          
          if data.number_value is not null then
            
            if hasNullFlag then
              putBytes(FL_NOT_NULL);
            end if;
          
            if fields(i).FixPointDecimals != 0 then
              data.number_value := data.number_value * fields(i).extPowerTen;
            end if;
            
            case fields(i).Type
            when QVX_SIGNED_INTEGER then
              if fields(i).ByteWidth <= 2 then
                putBytes(utl_raw.substr(utl_raw.cast_from_binary_integer(data.number_value, utl_raw.little_endian), 1, fields(i).ByteWidth));
              elsif fields(i).ByteWidth = 4 then
                putBytes(utl_raw.cast_from_binary_integer(data.number_value, utl_raw.little_endian));
              else
                putBytes(int64(data.number_value));
              end if;
            
            when QVX_IEEE_REAL then
              putBytes(utl_raw.cast_from_binary_double(data.number_value, utl_raw.little_endian));
            
            end case;
          
          else
            putBytes(FL_NULL);
          end if;
              
        when DBMS_SQL.DATE_TYPE then
          dbms_sql.column_value(c, i, data.date_value);
          --putString(to_char(data.date_value, fields(i).FieldFormat.extFmt));
          if data.date_value is not null then
            if hasNullFlag then
              putBytes(FL_NOT_NULL);
            end if;
            putBytes(utl_raw.cast_from_binary_double(data.date_value - OA_ZERO_DATE, utl_raw.little_endian));
          else
            putBytes(FL_NULL);
          end if;
              
        when DBMS_SQL.TIMESTAMP_TYPE then
          dbms_sql.column_value(c, i, data.ts_value);
          --putString(to_char(data.ts_value, fields(i).FieldFormat.extFmt));
          if data.ts_value is not null then
            if hasNullFlag then
              putBytes(FL_NOT_NULL);
            end if;
            putBytes(utl_raw.cast_from_binary_double(toOADate(data.ts_value), utl_raw.little_endian));
          else
            putBytes(FL_NULL);
          end if;
              
        when DBMS_SQL.TIMESTAMP_WITH_TZ_TYPE then
          dbms_sql.column_value(c, i, data.ts_tz_value);
          --putString(to_char(data.ts_tz_value, fields(i).FieldFormat.extFmt));
          if data.ts_tz_value is not null then
            if hasNullFlag then
              putBytes(FL_NOT_NULL);
            end if;
            putBytes(utl_raw.cast_from_binary_double(toOADate(data.ts_tz_value), utl_raw.little_endian));
          else
            putBytes(FL_NULL);
          end if;

        when DBMS_SQL.TIMESTAMP_WITH_LOCAL_TZ_TYPE then
          dbms_sql.column_value(c, i, data.ts_ltz_value);
          --putString(to_char(data.ts_tz_value, fields(i).FieldFormat.extFmt));
          if data.ts_ltz_value is not null then
            if hasNullFlag then
              putBytes(FL_NOT_NULL);
            end if;
            putBytes(utl_raw.cast_from_binary_double(toOADate(data.ts_ltz_value), utl_raw.little_endian));
          else
            putBytes(FL_NULL);
          end if;
              
        when DBMS_SQL.CLOB_TYPE then
          dbms_sql.column_value(c, i, data.clob_value);
          if data.clob_value is not null then
            if hasNullFlag then
              putBytes(FL_NOT_NULL);
            end if;
            putClob(data.clob_value);
          else
            putBytes(FL_NULL);
          end if;
          
        when DBMS_SQL.BLOB_TYPE then
          dbms_sql.column_value(c, i, data.blob_value);
          if data.blob_value is not null then
            if hasNullFlag then
              putBytes(FL_NOT_NULL);
            end if;
            putBlob(data.blob_value);
          else
            putBytes(FL_NULL);
          end if;
          
        end case;
          
      end loop;
    
    end loop;
    
    dbms_sql.close_cursor(c);
    
    if sz != 0 then
      --dbms_lob.writeappend(ctx.output, sz, buf);
      utl_file.put_raw(ctx.fd, buf);
    end if;
    
  end;
  
  function getContext(
    p_ctx_id  in ctxHandle
  ) 
  return context_t
  is
  begin
    return ctx_cache(p_ctx_id);
  exception
    when no_data_found then
      raise_application_error(-20001, 'invalid context handle');
  end;
  
  function newContext(
    p_tablename  in varchar2 default null
  )
  return ctxHandle
  is
    ctx_id  ctxHandle := nvl(ctx_cache.last,0) + 1;
    ctx     context_t;
  begin
    ctx.tableHeader.TableName := p_tablename;
    ctx.tableHeader.CreateUtcTime := cast(systimestamp at time zone 'UTC' as date);
    ctx_cache(ctx_id) := ctx;
    return ctx_id;
  end;

  function createContext(
    p_query      in varchar2
  , p_tablename  in varchar2 default null
  )
  return ctxHandle
  is
    ctx_id  ctxHandle := newContext(p_tablename);
    c       integer;
  begin
    c := dbms_sql.open_cursor();
    dbms_sql.parse(c, p_query, DBMS_SQL.NATIVE);
    ctx_cache(ctx_id).cursorNumber := c;
    ctx_cache(ctx_id).executeCursor := true;
    describeCursor(ctx_cache(ctx_id));
    return ctx_id;
  end;
  
  procedure bindVariable(
    p_ctx_id  in ctxHandle
  , p_name    in varchar2
  , p_value   in varchar2
  )
  is
  begin
    dbms_sql.bind_variable(getContext(p_ctx_id).cursorNumber, p_name, p_value);
  end;

  procedure bindVariable(
    p_ctx_id  in ctxHandle
  , p_name    in varchar2
  , p_value   in number
  )
  is
  begin
    dbms_sql.bind_variable(getContext(p_ctx_id).cursorNumber, p_name, p_value);
  end;
  
  procedure bindVariable(
    p_ctx_id  in ctxHandle
  , p_name    in varchar2
  , p_value   in date
  )
  is
  begin
    dbms_sql.bind_variable(getContext(p_ctx_id).cursorNumber, p_name, p_value);
  end;
  
  procedure closeContext(
    p_ctx_id  in ctxHandle
  )
  is
  begin
    ctx_cache.delete(p_ctx_id);
  end;

  procedure createFile(
    p_ctx_id     in ctxHandle
  , p_directory  in varchar2
  , p_filename   in varchar2
  )
  is
    ctx  context_t := getContext(p_ctx_id);
  begin
    --dbms_lob.createtemporary(ctx.output, true);
    ctx.fd := utl_file.fopen(p_directory, p_filename, 'wb', 32767);
    writeData(ctx);
    ctx_cache(p_ctx_id).nrows := ctx.nrows;
    utl_file.fclose(ctx.fd);
    --dbms_lob.freetemporary(ctx.output);
  exception
    when others then
      if utl_file.is_open(ctx.fd)then
        utl_file.fclose(ctx.fd);
      end if;
      raise_application_error(-20000, 'internal error' || chr(10) || 
                  dbms_utility.format_error_stack || 
                  dbms_utility.format_error_backtrace);
  end;
  
  procedure createFile(
    p_directory  in varchar2
  , p_filename   in varchar2
  , p_rc         in out nocopy sys_refcursor
  , p_tablename  in varchar2 default null
  )
  is
    ctx_id  ctxHandle := newContext(p_tablename);
  begin
    ctx_cache(ctx_id).cursorNumber := dbms_sql.to_cursor_number(p_rc);
    ctx_cache(ctx_id).executeCursor := false;
    describeCursor(ctx_cache(ctx_id));
    createFile(ctx_id, p_directory, p_filename);
    closeContext(ctx_id);
  end;
  
  procedure createFile(
    p_directory  in varchar2
  , p_filename   in varchar2
  , p_query      in varchar2
  , p_tablename  in varchar2 default null
  )
  is
    ctx_id  ctxHandle := createContext(p_query, p_tablename);
  begin
    createFile(ctx_id, p_directory, p_filename);
    closeContext(ctx_id);
  end;
  
  function getNumRows(
    p_ctx_id  in ctxHandle 
  )
  return integer
  is
  begin
    return getContext(p_ctx_id).nrows;
  end;

end xutl_qvx;
/
