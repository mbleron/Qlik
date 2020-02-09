
# QVXGen - An Oracle PL/SQL Utility to Generate Qlik QVX Files

Qlik products (QlikView and Qlik Sense) are popular in the BI/Data Visualisation ecosystem.
Although both can deal with a variety of data sources (flat files, Excel, XML, ODBC ...), Qlik also provides an open data exchange format (QVX) for efficient data loading, especially from third-party sources.  
A QVX file consists in an XML header containing metadata (field descriptions), followed by a data stream structured according to the header.

QVXGen provides an easy way to generate a QVX file out of relational data, from a SQL query or a REF cursor.

## Content
* [What's New in...](#whats-new-in)  
* [Bug tracker](#bug-tracker)  
* [Installation](#installation)  
* [Quick Start](#quick-start)
* [QVXGen Subprograms and Usage](#qvxgen-subprograms-and-usage)  
* [CHANGELOG](#changelog)  


## What's New in...
> Version 1.0 : 
> Initial version

## Bug tracker

Found a bug, have a question, or an enhancement request?  
Please create an issue [here](https://github.com/mbleron/Qlik/issues).


## Installation

### Getting source code

Clone this repository or download it as a zip archive.

### Database requirement

QVXGen requires Oracle Database 11\.2\.0\.1 and onwards.

### PL/SQL

Using SQL*Plus, connect to the target database schema and run script [`install.sql`](./install.sql).


## Quick Start

Creating a QVX file from a SQL query : 
```sql
begin
  xutl_qvx.createFile('QVX_DIR', 'test.qvx', 'select * from my_table');
end;
/
```

Creating a QVX file from a REF cursor : 
```sql
declare
  rc  sys_refcursor;
begin
  open rc for select * from my_table;
  xutl_qvx.createFile('QVX_DIR', 'test.qvx', rc, 'MY_TABLE');
end;
/
```

Creating a QVX file from a SQL query with bind variables : 
```sql
declare
  ctx_id  xutl_qvx.ctxHandle;
begin
  ctx_id := xutl_qvx.createContext(
              p_query => 'select * from my_table where update_date < :1'
            , p_tablename => 'MY_TABLE'
            );
  xutl_qvx.bindVariable(ctx_id, '1', sysdate);
  xutl_qvx.createFile(ctx_id, 'QVX_DIR', 'test.qvx');
  xutl_qvx.closeContext(ctx_id);
end;
/
```

See the following sections for a detailed description of QVXGen features.

## QVXGen Subprograms and Usage

* [createContext](#createcontext-function)  
* [bindVariable](#bindvariable-procedure)  
* [closeContext](#closecontext-procedure)  
* [createFile](#createfile-procedure)  
---

### createContext function
Creates a new context handle from a SQL query string.  
This function is useful when the query has variable(s) that must be bound at runtime.

```sql
function createContext(
  p_query      in varchar2
, p_tablename  in varchar2 default null
)
return ctxHandle;
```

Parameter|Description|Mandatory
---|---|---
`p_query`|SQL query string.|Yes
`p_tablename`|Optional data source description.|No


---
### bindVariable procedure
This procedure binds a variable value to the query associated with the given context handle.  
It is available as overloads for the three most common data types : NUMBER, VARCHAR2 and DATE.

```sql
procedure bindVariable(
  p_ctx_id  in ctxHandle
, p_name    in varchar2
, p_value   in number
);
```

```sql
procedure bindVariable(
  p_ctx_id  in ctxHandle
, p_name    in varchar2
, p_value   in varchar2
);
```

```sql
procedure bindVariable(
  p_ctx_id  in ctxHandle
, p_name    in varchar2
, p_value   in date
);
```

Parameter|Description|Mandatory
---|---|---
`p_ctx_id`|Context handle, as returned from a previous call to [createContext](#createcontext-function).|Yes
`p_name`|Bind variable name.|Yes
`p_value`|Bind variable value.|Yes


---
### closeContext procedure
Closes a context handle previously opened with [createContext](#createcontext-function). 

```sql
procedure closeContext(
  p_ctx_id  in ctxHandle
);
```

Parameter|Description|Mandatory
---|---|---
`p_ctx_id`|Context handle.|Yes


---
### createFile procedure
Writes the QVX file to disk.  
This procedure is available as three overloads, depending on how the source SQL query has been specified : context handle, string or REF cursor.

```sql
procedure createFile(
  p_ctx_id     in ctxHandle
, p_directory  in varchar2
, p_filename   in varchar2
);
```

```sql
procedure createFile(
  p_directory  in varchar2
, p_filename   in varchar2
, p_query      in varchar2
, p_tablename  in varchar2 default null
);
```

```sql
procedure createFile(
  p_directory  in varchar2
, p_filename   in varchar2
, p_rc         in out nocopy sys_refcursor
, p_tablename  in varchar2 default null
);
```

Parameter|Description|Mandatory
---|---|---
`p_ctx_id`|Context handle.|Yes
`p_directory`|Target file directory (must be an Oracle directory name).|Yes
`p_filename`|QVX file name.|Yes
`p_query`|SQL query string.|Yes
`p_rc`|REF cursor.|Yes
`p_tablename`|Optional data source description.|No


## References

QlikView® for developers : [QVX file format](https://help.qlik.com/en-US/qlikview-developer/April2019/Subsystems/QVXSDKAPI/Content/QV_QVXSDKAPI/QlikView%20QVX%20File%20Format/QVX-file-format1.htm)

## CHANGELOG

### 1.0 (2019-12-01)

* Creation



## Copyright and license

Copyright 2019-2020 Marc Bleron. Released under MIT license.
