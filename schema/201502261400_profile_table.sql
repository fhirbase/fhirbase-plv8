CREATE TABLE search_type_to_type AS
        SELECT 'date' as stp,  '{date,dateTime,instant,Period,Timing}'::text[] as tp
  UNION SELECT 'token' as stp, '{boolean,code,CodeableConcept,Coding,Identifier,oid,Resource,string,uri}'::text[] as tp
  UNION SELECT 'string' as stp, '{Address,Attachment,CodeableConcept,ContactPoint,HumanName,Period,Quantity,Ratio,Resource,SampledData,string,uri}'::text[] as tp
  UNION SELECT 'number' as stp, '{integer,decimal,Duration,Quantity}'::text[] as tp
  UNION SELECT 'reference' as stp, '{Reference}'::text[] as tp
  UNION SELECT 'quantity' as stp, '{Quantity}'::text[] as tp;
