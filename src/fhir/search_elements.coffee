summary_to_elements = (plv8, idx, elemnts)->

# a,a.b,c,a.b.d => [[a, [[b, [d]]], [c]]]
param_to_elements = (elements)->


# {a: {c: 1, d: 3}, b: 2}, ['a.c'] => {a: {c: 1}}
mask = (resource, elements)->
