token_idx_fn = (p)->
  res = if p.is_primitive then "primitive_as_token" else "#{p.type.toLowerCase()}_as_token"
  "index_#{res}"

quote_array = (plv8, pth)->
  vls = pth.map(plv8.quote_literal).join(",")
  "ARRAY[#{vls}]"

mk_array_cnd = (plv8, idx_fn, p)->
  tbl = plv8.quote_ident(p.table_name)
  pth = quote_array(plv8, p.path)
  vls = quote_array(plv8, p.value)
  "(fhirbase_idx_fns.#{idx_fn}(#{tbl}.content, #{pth}) && #{vls})"

mk_date_range_cnd = (plv8, p, rng_fn)->
   tbl = plv8.quote_ident(p.table_name)
   pth = quote_array(plv8, p.path)
   tp = plv8.quote_literal(p.type)
   res = p.value
     .map (x)->  rng_fn(plv8.quote_literal(x))
     .map (vl)-> "fhirbase_date_idx.index_as_date(#{tbl}.content, #{pth}, #{tp}::text) && #{vl}"
     .join(' OR ')

   "(#{res})"

CONDITIONS =
  identifier:
    any: (plv8, p)->
      vals = p.value.map((x)-> plv8.quote_literal(x)).join(',')
      tbl = plv8.quote_ident(p.table_name)
      "(#{tbl}.logical_id IN(#{vals}))"
  string:
    eq: (plv8, p)->
      tbl = plv8.quote_ident(p.table_name)
      pth = quote_array(plv8, p.path)
      res = p.value
        .map((x)-> plv8.quote_literal("%#{x}%"))
        .map((x)-> "fhirbase_idx_fns.index_as_string_eq(#{tbl}.content, #{pth}) ilike #{x}")
        .join(" OR ")
      "(#{res})"
    exact: (plv8, p)-> mk_array_cnd(plv8, 'index_as_string_exact', p)
  token:
    eq:    (plv8, p)-> mk_array_cnd(plv8, token_idx_fn(p), p)
  reference:
    any:   (plv8, p)-> mk_array_cnd(plv8, 'index_as_reference', p)
  date:
    eq: (plv8, p)->
      mk_date_range_cnd(plv8, p, ((x)->"fhirbase_date_idx._datetime_to_tstzrange(#{x}, #{x})")) 
    gt: (plv8, p)->
      mk_date_range_cnd(plv8, p, ((x)-> "fhirbase_date_idx._datetime_to_tstzrange(#{x}, NULL)"))
    lt: (plv8, p)->
      mk_date_range_cnd(plv8, p, ((x)-> "('(,' || fhirbase_date_idx._date_parse_to_upper(#{x}) || ']' )::tstzrange"))
    ge: (plv8, p)->
      mk_date_range_cnd(plv8, p, ((x)-> "('[,' || fhirbase_date_idx._date_parse_to_upper(#{x}) || ']' )::tstzrange"))
    le: (plv8, p)->
      mk_date_range_cnd(plv8, p, ((x)-> "('[' || fhirbase_date_idx._date_parse_to_lower(#{x}) || ',)' )::tstzrange"))

exports.CONDITIONS = CONDITIONS

conditions = (plv8, res_type, params)->
  res = for p in params when !p.chain
    cnd = CONDITIONS[p.search_type]
    throw new Error("Not supported type #{p.search_type}") unless cnd
    cndb = cnd[p.op] || cnd.any
    throw new Error("Not supported operation #{p.op}") unless cndb
    cndb(plv8, p)
  res.join "\n AND"
