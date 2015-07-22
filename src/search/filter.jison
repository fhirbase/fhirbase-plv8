%lex
%%
\s+            {/* ignore */}
"("            { return '(';}
")"            { return ')';}
"."            { return '.';}
not            { return 'NOT';}
[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9] { return 'DATE';}
(and|or)       { return 'LOGICAL';}
(eq|ne|co|sw|ew|gt|lt|ge|le|pr|po|ss|sb|in|ni|re)   { return 'CMP_OPERATOR';}
\w(\w|-|_)+    { return 'IDENT';}
\w(\w|-|_)+    { return 'TOKEN';}
["][^"]+["]    { return 'STRING';}
[0-9]+.?[0-9]? { return 'NUMBER';}
<<EOF>>        { return 'EOF';}
/lex

%left LOGICAL

%%

file: filter EOF { return $filter; };

filter
  : paramExp
    { $$ = $1;}
  | logExp
    { $$ = $1;}
  | NOT "(" filter ")"
    { $$ = ['not',$3];}
  ;

logExp
  : filter (LOGICAL filter)
    { $$ = [$2, $1, $3]; }
  ;

paramExp
  : paramPath CMP_OPERATOR compValue
    { $$ = [$2,$1,$3];}
  ;

compValue
  : STRING
    { $$ = ['string', $1.replace(/(^"|"$)/g, "")];}
  | DATE
    { $$ = ['date', $1];}
  | NUMBER
    { $$ = ['number', $1];}
  | TOKEN
    { $$ = ['token', $1];}
  ;

paramPath
  : IDENT "." paramPath
    { $$ = $paramPath; $$.unshift($1) }
  | IDENT
    { $$ = [$1];}
  ;
