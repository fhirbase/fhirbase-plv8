
proc xspath(pth varchar, x xml) returns xml[]
  --- @private
  --- HACK: see http://joelonsql.com/2013/05/13/xml-madness/
  --- problems with namespaces
  BEGIN
    RETURN  xpath('/xml' || pth, xml('<xml xmlns:xs="xs">' || x || '</xml>'), ARRAY[ARRAY['xs','xs']]);

proc xsattr(pth varchar, x xml) returns varchar
  --- @private
  BEGIN
    RETURN unnest(this.xspath( pth,x)) limit 1;
