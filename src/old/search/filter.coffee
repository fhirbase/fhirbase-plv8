fs = require("fs")
jison = require("jison")

bnf = fs.readFileSync("#{__dirname}/filter.jison", "utf8")
parser = new jison.Parser(bnf)



mkbinop = (op)->
  (ast)->
    "#{ast[1]} #{op} #{to_sql(ast[2])}"

ops = {
  string: (x)-> "'#{x[1]}'"
  number: (x)-> x[1]
  date: (x)-> "'#{x[1]}'"
  eq: mkbinop('=')
  and: (ast)-> "(#{to_sql(ast[1])} AND #{to_sql(ast[2])})"
  ge: mkbinop('>')
  le: mkbinop('>')
}

to_sql = (ast)->
  x = ast[0]
  fn = ops[x]
  return "FAIL" unless fn
  fn(ast)

strs = [
  'name eq "ups"'
  'given eq "peter" and birthdate ge 2014-10-10'
]

for str in strs
  ast = parser.parse(str)
  console.log '----'
  console.log str, ' => '
  console.log JSON.stringify(ast), ' => '
  console.log to_sql(ast)
