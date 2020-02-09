create or replace package xutl_qvx is
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
  
  subtype ctxHandle is pls_integer;

  procedure setDebug(status in boolean);

  function createContext(
    p_query      in varchar2
  , p_tablename  in varchar2 default null
  )
  return ctxHandle;
  
  procedure bindVariable(
    p_ctx_id  in ctxHandle
  , p_name    in varchar2
  , p_value   in varchar2
  );

  procedure bindVariable(
    p_ctx_id  in ctxHandle
  , p_name    in varchar2
  , p_value   in number
  );
  
  procedure bindVariable(
    p_ctx_id  in ctxHandle
  , p_name    in varchar2
  , p_value   in date
  );
  
  procedure closeContext(
    p_ctx_id  in ctxHandle
  );

  procedure createFile(
    p_ctx_id     in ctxHandle
  , p_directory  in varchar2
  , p_filename   in varchar2
  );
  
  procedure createFile(
    p_directory  in varchar2
  , p_filename   in varchar2
  , p_rc         in out nocopy sys_refcursor
  , p_tablename  in varchar2 default null
  );
  
  procedure createFile(
    p_directory  in varchar2
  , p_filename   in varchar2
  , p_query      in varchar2
  , p_tablename  in varchar2 default null
  );

  function getNumRows(
    p_ctx_id  in ctxHandle 
  )
  return integer;

end xutl_qvx;
/
