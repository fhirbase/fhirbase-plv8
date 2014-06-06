--db:fhirb
--{{{


--}}}

SELECT * FROM index_string_complex_type(
  '{Patient,address}',
  $JSON$
    {
      "use": "home",
      "line": [
        "534 Erewhon St"
      ],
      "city": "PleasantVille",
      "state": "Vic",
      "zip": "3999"
    }
  $JSON$
);

--{{{
\set pt `curl http://www.hl7.org/implement/standards/fhir/patient-example.json`

SELECT unnest(index_string_resource(:'pt'::jsonb));
--}}}

--{{{
\set subj `curl http://www.hl7.org/implement/standards/fhir/relatedperson-example-f002-ariadne.json`

SELECT unnest(index_string_resource(:'subj'::jsonb));
--}}}
