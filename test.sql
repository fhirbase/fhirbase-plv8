-- Compile src/core.coffee
Compile module /root/fhirbase-plv8/src/core.coffee...
SCHEMA undefined
Compile module ./core/core...
SCHEMA undefined
Compile module ./crud...
SCHEMA core
Compile fn create...
Compile fn read...
Compile fn vread...
Compile fn update...
Compile fn delete...
Compile module ./namings...
SCHEMA undefined
Compile module ./pg_meta...
SCHEMA undefined
Compile module ./utils...
SCHEMA undefined
Compile module ../honey...
SCHEMA undefined
Compile module ./bundle...
SCHEMA undefined
Compile module ./schema...
SCHEMA undefined
Compile module ./search...
SCHEMA undefined
CREATE OR REPLACE FUNCTION plv8_init() RETURNS text AS $$
  var _modules = {};
  var _current_file = null;
  var _current_dir = null;

  // modules start
  _modules["/root/fhirbase-plv8/src/core"] = {
  init:  function(){
    var exports = {};
    _current_file = "core";
    _current_dir = "/root/fhirbase-plv8/src";
    var module = {exports: exports};
    (function() {
  require('./core/core');

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/core"] = {
  init:  function(){
    var exports = {};
    _current_file = "core";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  require('./crud');

  require('./namings');

  require('./pg_meta');

  require('./schema');

  require('./search');

  require('./utils');

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/crud"] = {
  init:  function(){
    var exports = {};
    _current_file = "crud";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  var assert, bundle, ensure_meta, ensure_table, namings, pg_meta, utils, validate_create_resource;

  namings = require('./namings');

  pg_meta = require('./pg_meta');

  utils = require('./utils');

  bundle = require('./bundle');

  exports.plv8_schema = "core";

  validate_create_resource = function(resource) {
    if (!resource.resourceType) {
      return {
        status: "Error",
        message: "resource should have type element"
      };
    }
  };

  assert = function(pred, msg) {
    if (!pred) {
      throw new Error("Asserted: " + msg);
    }
  };

  ensure_meta = function(resource, props) {
    var k, v;
    resource.meta || (resource.meta = {});
    for (k in props) {
      v = props[k];
      resource.meta[k] = v;
    }
    return resource;
  };

  ensure_table = function(plv8, resourceType) {
    var table_name;
    table_name = namings.table_name(plv8, resourceType);
    if (!pg_meta.table_exists(plv8, table_name)) {
      return [
        null, {
          status: "Error",
          message: "Table " + table_name + " for " + resourceType + " not exists"
        }
      ];
    } else {
      return [table_name, null];
    }
  };

  exports.create = function(plv8, resource) {
    var errors, id, ref, table_name, version_id;
    errors = validate_create_resource(resource);
    if (errors) {
      return errors;
    }
    ref = ensure_table(plv8, resource.resourceType), table_name = ref[0], errors = ref[1];
    if (errors) {
      return errors;
    }
    id = resource.id || utils.uuid(plv8);
    resource.id = id;
    version_id = (resource.meta && resource.meta.versionId) || utils.uuid(plv8);
    ensure_meta(resource, {
      versionId: version_id,
      lastUpdated: new Date(),
      request: {
        method: 'POST',
        url: resource.resourceType
      }
    });
    utils.exec(plv8, {
      insert: table_name,
      values: {
        id: id,
        version_id: version_id,
        resource: resource,
        created_at: '^CURRENT_TIMESTAMP',
        updated_at: '^CURRENT_TIMESTAMP'
      }
    });
    utils.exec(plv8, {
      insert: ['history', table_name],
      values: {
        id: id,
        version_id: version_id,
        resource: resource,
        valid_from: '^CURRENT_TIMESTAMP',
        valid_to: '^CURRENT_TIMESTAMP'
      }
    });
    return resource;
  };

  exports.create.plv8_signature = ['jsonb', 'jsonb'];

  exports.read = function(plv8, query) {
    var errors, ref, res, row, table_name;
    assert(query.id, 'query.id');
    assert(query.resourceType, 'query.resourceType');
    ref = ensure_table(plv8, query.resourceType), table_name = ref[0], errors = ref[1];
    if (errors) {
      return errors;
    }
    res = utils.exec(plv8, {
      select: [':*'],
      from: [table_name],
      where: {
        id: query.id
      }
    });
    row = res[0];
    if (!row) {
      return {
        status: "Error",
        message: "Not found"
      };
    }
    return JSON.parse(row.resource);
  };

  exports.read.plv8_signature = ['jsonb', 'jsonb'];

  exports.vread = function(plv8, query) {
    var errors, q, ref, res, row, table_name, version_id;
    assert(query.id, 'query.id');
    version_id = query.versionId || query.meta.versionId;
    assert(version_id, 'query.versionId or query.meta.versionId');
    assert(query.resourceType, 'query.resourceType');
    ref = ensure_table(plv8, query.resourceType), table_name = ref[0], errors = ref[1];
    if (errors) {
      return errors;
    }
    q = {
      select: [':*'],
      from: ["history." + table_name],
      where: {
        id: query.id,
        version_id: version_id
      }
    };
    res = utils.exec(plv8, q);
    row = res[0];
    if (!row) {
      return {
        status: "Error",
        message: "Not found"
      };
    }
    return JSON.parse(row.resource);
  };

  exports.vread.plv8_signature = ['jsonb', 'jsonb'];

  exports.update = function(plv8, resource) {
    var errors, id, old_version, ref, table_name, version_id;
    id = resource.id;
    assert(id, 'resource.id');
    assert(resource.resourceType, 'resource.resourceType');
    ref = ensure_table(plv8, resource.resourceType), table_name = ref[0], errors = ref[1];
    if (errors) {
      return errors;
    }
    old_version = exports.read(plv8, resource);
    if (!old_version) {
      return {
        status: "Error",
        message: "Resource " + resource.resourceType + "/" + id + " not exists"
      };
    }
    version_id = utils.uuid(plv8);
    ensure_meta(resource, {
      versionId: version_id,
      lastUpdated: new Date(),
      request: {
        method: 'PUT',
        url: resource.resourceType
      }
    });
    utils.exec(plv8, {
      update: table_name,
      where: {
        id: id
      },
      values: {
        version_id: version_id,
        resource: resource,
        updated_at: '^CURRENT_TIMESTAMP'
      }
    });
    utils.exec(plv8, {
      update: ['history', table_name],
      where: {
        id: id,
        version_id: old_version.meta.versionId
      },
      values: {
        valid_to: '^CURRENT_TIMESTAMP'
      }
    });
    utils.exec(plv8, {
      insert: ['history', table_name],
      values: {
        id: id,
        version_id: version_id,
        resource: resource,
        valid_from: '^CURRENT_TIMESTAMP',
        valid_to: "^'infinity'"
      }
    });
    return resource;
  };

  exports.update.plv8_signature = ['jsonb', 'jsonb'];

  exports["delete"] = function(plv8, resource) {
    var errors, id, old_version, ref, table_name, version_id;
    id = resource.id;
    assert(id, 'resource.id');
    assert(resource.resourceType, 'resource.resourceType');
    ref = ensure_table(plv8, resource.resourceType), table_name = ref[0], errors = ref[1];
    if (errors) {
      return errors;
    }
    old_version = exports.read(plv8, resource);
    if (!old_version) {
      return {
        status: "Error",
        message: "Resource " + resource.resourceType + "/" + id + " not exists"
      };
    }
    resource = utils.copy(old_version);
    version_id = utils.uuid(plv8);
    ensure_meta(resource, {
      versionId: version_id,
      lastUpdated: new Date(),
      request: {
        method: 'DELETE',
        url: resource.resourceType
      }
    });
    utils.exec(plv8, {
      "delete": table_name,
      where: {
        id: id
      }
    });
    utils.exec(plv8, {
      update: ['history', table_name],
      where: {
        id: id,
        version_id: old_version.meta.versionId
      },
      values: {
        valid_to: '^CURRENT_TIMESTAMP'
      }
    });
    utils.exec(plv8, {
      insert: ['history', table_name],
      values: {
        id: id,
        version_id: version_id,
        resource: resource,
        valid_from: '^CURRENT_TIMESTAMP',
        valid_to: '^CURRENT_TIMESTAMP'
      }
    });
    return resource;
  };

  exports["delete"].plv8_signature = ['jsonb', 'jsonb'];

  exports.history = function(plv8, query) {
    var errors, id, ref, resources, table_name;
    id = query.id;
    assert(id, 'query.id');
    assert(query.resourceType, 'query.resourceType');
    ref = ensure_table(plv8, query.resourceType), table_name = ref[0], errors = ref[1];
    if (errors) {
      return errors;
    }
    resources = utils.exec(plv8, {
      select: [':*'],
      from: ["history." + table_name],
      where: {
        id: query.id
      }
    }).map(function(x) {
      return JSON.parse(x.resource);
    });
    return bundle.history_bundle(resources);
  };

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/namings"] = {
  init:  function(){
    var exports = {};
    _current_file = "namings";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  exports.table_name = function(plv8, resource_name) {
    if (!resource_name) {
      throw new Error("expected resource_name");
    }
    return resource_name.toLowerCase();
  };

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/pg_meta"] = {
  init:  function(){
    var exports = {};
    _current_file = "pg_meta";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  var table_exists, utils;

  utils = require('./utils');

  table_exists = function(plv8, table_name) {
    var parts, result, schema_name;
    parts = table_name.split('.');
    if (parts.length > 1) {
      schema_name = parts[0];
      table_name = parts[1];
    } else {
      schema_name = 'public';
      table_name = table_name;
    }
    result = utils.exec(plv8, {
      select: ['^true'],
      from: ['information_schema.tables'],
      where: [':and', [':=', ':table_name', table_name], [':=', ':table_schema', schema_name]]
    });
    return result.length > 0;
  };

  exports.table_exists = table_exists;

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/utils"] = {
  init:  function(){
    var exports = {};
    _current_file = "utils";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  var sql, uuid;

  sql = require('../honey');

  uuid = function(plv8) {
    return plv8.execute('select gen_random_uuid() as uuid')[0].uuid;
  };

  exports.uuid = uuid;

  exports.copy = function(x) {
    return JSON.parse(JSON.stringify(x));
  };

  exports.exec = function(plv8, hql) {
    var q;
    q = sql(hql);
    return plv8.execute.call(plv8, q[0], q.slice(1));
  };

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/honey"] = {
  init:  function(){
    var exports = {};
    _current_file = "honey";
    _current_dir = "/root/fhirbase-plv8/src";
    var module = {exports: exports};
    (function() {
  var RAW_SQL_REGEX, SPECIALS, _toLiteral, _to_array, _to_table_name, assert, assertArray, coerce_param, comment, concat, emit_columns, emit_columns_ddl, emit_create, emit_create_extension, emit_create_schema, emit_create_table, emit_delete, emit_delimit, emit_drop, emit_expression, emit_expression_by_sample, emit_insert, emit_join, emit_param, emit_qualified_name, emit_select, emit_table_name, emit_tables, emit_update, emit_where, interpose, isArray, isKeyword, isNumber, isObject, isRawSql, isString, keys, name, push, quote_ident, quote_litteral, rawToSql, sql, surround, surround_parens;

  isArray = function(value) {
    return value && typeof value === 'object' && value instanceof Array && typeof value.length === 'number' && typeof value.splice === 'function' && !(value.propertyIsEnumerable('length'));
  };

  isObject = function(x) {
    return x !== null && typeof x === 'object';
  };

  isKeyword = function(x) {
    return isString(x) && x.indexOf && x.indexOf(':') === 0;
  };

  isNumber = function(x) {
    return !isNaN(parseFloat(x)) && isFinite(x);
  };

  name = function(x) {
    if (isKeyword(x)) {
      return x.replace(/^:/, '');
    }
  };

  assertArray = function(x) {
    if (!isArray(x)) {
      throw new Error('from: [array] expected)');
    }
  };

  assert = function(x, msg) {
    if (!x) {
      throw new Error(x);
    }
  };

  interpose = function(sep, col) {
    return col.reduce((function(acc, x) {
      acc.push(x);
      acc.push(sep);
      return acc;
    }), []).slice(0, -1);
  };

  isString = function(x) {
    return typeof x === 'string';
  };

  push = function(acc, x) {
    acc.result.push(x);
    return acc;
  };

  concat = function(acc, xs) {
    acc.result = acc.result.concat(xs);
    return acc;
  };

  RAW_SQL_REGEX = /^\^/;

  isRawSql = function(x) {
    return x && isString(x) && x.match(RAW_SQL_REGEX);
  };

  rawToSql = function(x) {
    return x.replace(RAW_SQL_REGEX, '');
  };

  _toLiteral = function(x) {
    if (isKeyword(x)) {
      return name(x);
    } else if (isRawSql(x)) {
      return rawToSql(x);
    } else if (isNumber(x)) {
      return x;
    } else if (isObject(x)) {
      return JSON.stringify(x);
    } else {
      return "'" + x + "'";
    }
  };

  quote_litteral = function(x) {
    return "'" + x + "'";
  };

  quote_ident = function(x) {
    return x.split('.').map(function(x) {
      return "\"" + x + "\"";
    }).join('.');
  };

  coerce_param = function(x) {
    if (isObject(x)) {
      return JSON.stringify(x);
    } else {
      return x;
    }
  };

  emit_param = function(acc, v) {
    if (isRawSql(v)) {
      push(acc, rawToSql(v));
    } else if (isKeyword(v)) {
      push(acc, name(v));
    } else {
      push(acc, "$" + acc.cnt);
      acc.cnt = acc.cnt + 1;
      acc.params.push(coerce_param(v));
    }
    return acc;
  };

  surround = function(acc, parens, proc) {
    push(acc, parens[0]);
    acc = proc(acc);
    push(acc, parens[1]);
    return acc;
  };

  surround_parens = function(acc, proc) {
    return surround(acc, ['(', ')'], proc);
  };

  emit_delimit = function(acc, delim, xs, next) {
    var i, k, len, ref, v, x;
    if (!isArray(xs)) {
      xs = (function() {
        var results;
        results = [];
        for (k in xs) {
          v = xs[k];
          results.push([k, v]);
        }
        return results;
      })();
    }
    ref = xs.slice(0, -1);
    for (i = 0, len = ref.length; i < len; i++) {
      x = ref[i];
      acc = next(acc, x);
      push(acc, delim);
    }
    acc = next(acc, xs[xs.length - 1]);
    return acc;
  };

  emit_columns = function(acc, xs) {
    return emit_delimit(acc, ",", xs, function(acc, x) {
      if (isKeyword(x)) {
        push(acc, name(x));
      } else if (isRawSql(x)) {
        push(acc, rawToSql(x));
      } else {
        acc = emit_param(acc, x);
      }
      return acc;
    });
  };

  emit_qualified_name = function(acc, y) {
    if (isArray(y)) {
      return push(acc, y.map(quote_ident).join('.'));
    } else {
      return push(acc, quote_ident(y));
    }
  };

  emit_table_name = function(acc, y) {
    if (isArray(y)) {
      return push(acc, (quote_ident(y[0])) + " " + y[1]);
    } else {
      return push(acc, quote_ident(y));
    }
  };

  emit_tables = function(acc, x) {
    assert(x, 'from: [tables] expected');
    assertArray(x);
    push(acc, "FROM");
    return emit_delimit(acc, ",", x, emit_table_name);
  };

  SPECIALS = {
    between: function(acc, xs) {
      emit_expression(acc, xs[1]);
      push(acc, "BETWEEN");
      emit_param(acc, xs[2][0]);
      push(acc, "AND");
      emit_param(acc, xs[2][1]);
      return acc;
    },
    "in": function(acc, xs) {
      emit_expression(acc, xs[1]);
      push(acc, "IN");
      return surround_parens(acc, function(acc) {
        return emit_delimit(acc, ",", xs[2], function(acc, x) {
          return emit_param(acc, x);
        });
      });
    }
  };

  emit_expression = function(acc, xs) {
    var special, which;
    if (!isArray(xs)) {
      push(acc, _toLiteral(xs));
    } else {
      which = xs[0];
      switch (which) {
        case ':and':
          surround_parens(acc, function(acc) {
            return emit_delimit(acc, "AND", xs.slice(1), emit_expression);
          });
          break;
        case ':or':
          surround_parens(acc, function(acc) {
            return emit_delimit(acc, "OR", xs.slice(1), emit_expression);
          });
          break;
        default:
          special = SPECIALS[name(which)];
          if (special) {
            special(acc, xs);
          } else {
            emit_expression(acc, xs[1]);
            emit_expression(acc, xs[0]);
            emit_param(acc, xs[2]);
          }
      }
    }
    return acc;
  };

  emit_expression_by_sample = function(acc, obj) {
    return surround_parens(acc, function(acc) {
      emit_delimit(acc, 'AND', obj, function(acc, arg) {
        var k, v;
        k = arg[0], v = arg[1];
        push(acc, k);
        push(acc, "=");
        return emit_param(acc, v);
      });
      return acc;
    });
  };

  emit_where = function(acc, x) {
    if (!x) {
      return acc;
    }
    push(acc, "WHERE");
    if (isArray(x)) {
      return emit_expression(acc, x);
    } else if (isObject(x)) {
      return emit_expression_by_sample(acc, x);
    } else {
      throw new Error('unexpected where section');
    }
  };

  emit_join = function(acc, xs) {
    var i, len, x;
    if (!xs) {
      return acc;
    }
    for (i = 0, len = xs.length; i < len; i++) {
      x = xs[i];
      push(acc, "JOIN");
      emit_table_name(acc, x[0]);
      push(acc, "ON");
      emit_expression(acc, x[1]);
    }
    return acc;
  };

  emit_select = function(acc, query) {
    push(acc, "SELECT");
    emit_columns(acc, query.select);
    emit_tables(acc, query.from);
    if (query.join) {
      emit_join(acc, query.join);
    }
    emit_where(acc, query.where);
    if (query.limit) {
      push(acc, "LIMIT");
      push(acc, query.limit);
    }
    if (query.offset) {
      push(acc, "OFFSET");
      push(acc, query.offset);
    }
    return acc;
  };

  _to_table_name = function(x) {
    if (isArray(x)) {
      return x.map(quote_ident).join('.');
    } else {
      return quote_ident(x);
    }
  };

  _to_array = function(x) {
    if (isArray(x)) {
      return x;
    } else if (x) {
      return [x];
    } else {
      return [];
    }
  };

  keys = function(obj) {
    var _, k, results;
    results = [];
    for (k in obj) {
      _ = obj[k];
      results.push(k);
    }
    return results;
  };

  emit_columns_ddl = function(acc, q) {
    var cols;
    if (!q.columns) {
      return acc;
    }
    cols = keys(q.columns).sort();
    return emit_delimit(acc, ",", cols, function(acc, c) {
      push(acc, quote_ident(c));
      return push(acc, _to_array(q.columns[c]).join(' '));
    });
  };

  emit_create_table = function(acc, q) {
    push(acc, "CREATE TABLE");
    emit_qualified_name(acc, q.name);
    surround_parens(acc, function(acc) {
      return emit_columns_ddl(acc, q);
    });
    if (q.inherits) {
      push(acc, "INHERITS");
      surround_parens(acc, function(acc) {
        return emit_delimit(acc, ",", q.inherits, emit_qualified_name);
      });
    }
    return acc;
  };

  emit_create_extension = function(acc, q) {
    push(acc, "CREATE EXTENSION IF NOT EXISTS");
    return push(acc, q.name);
  };

  emit_create_schema = function(acc, q) {
    push(acc, "CREATE SCHEMA IF NOT EXISTS");
    return push(acc, q.name);
  };

  emit_insert = function(acc, q) {
    var k, names, params, ref, v, values;
    push(acc, "INSERT");
    push(acc, "INTO");
    emit_qualified_name(acc, q.insert);
    names = [];
    values = [];
    params = [];
    ref = q.values;
    for (k in ref) {
      v = ref[k];
      names.push(k);
      if (isRawSql(v)) {
        values.push(rawToSql(v));
      } else {
        values.push("$" + acc.cnt);
        acc.params.push(coerce_param(v));
        acc.cnt = acc.cnt + 1;
      }
    }
    surround_parens(acc, function(acc) {
      return emit_delimit(acc, ',', names, function(acc, nm) {
        return push(acc, nm);
      });
    });
    push(acc, "VALUES");
    surround_parens(acc, function(acc) {
      return emit_delimit(acc, ',', values, function(acc, v) {
        return push(acc, v);
      });
    });
    return acc;
  };

  emit_update = function(acc, q) {
    push(acc, "UPDATE");
    emit_qualified_name(acc, q.update);
    push(acc, "SET");
    acc = emit_delimit(acc, ",", q.values, function(acc, arg) {
      var k, v;
      k = arg[0], v = arg[1];
      push(acc, k + " =");
      return emit_param(acc, v);
    });
    return emit_where(acc, q.where);
  };

  emit_create = function(acc, q) {
    switch (q.create) {
      case 'table':
        return emit_create_table(acc, q);
      case 'extension':
        return emit_create_extension(acc, q);
      case 'schema':
        return emit_create_schema(acc, q);
    }
  };

  emit_drop = function(acc, q) {
    push(acc, "DROP");
    push(acc, q.drop);
    if (q.safe) {
      push(acc, "IF EXISTS");
    }
    return push(acc, _to_table_name(q.name));
  };

  emit_delete = function(acc, q) {
    push(acc, "DELETE FROM");
    emit_qualified_name(acc, q["delete"]);
    return emit_where(acc, q.where);
  };

  sql = function(q) {
    var acc, res;
    acc = {
      cnt: 1,
      result: [],
      params: []
    };
    acc = q.create ? emit_create(acc, q) : q.insert ? emit_insert(acc, q) : q.update ? emit_update(acc, q) : q.drop ? emit_drop(acc, q) : q["delete"] ? emit_delete(acc, q) : q.select ? emit_select(acc, q) : void 0;
    res = [acc.result.join(" ")].concat(acc.params);
    return res;
  };

  module.exports = sql;

  sql.TZ = "TIMESTAMP WITH TIME ZONE";

  sql.JSONB = "jsonb";

  comment = function() {
    console.log(sql({
      select: [":a", "^b", 'c'],
      from: ['users', 'roles'],
      joins: [['roles', [':=', '^r.user_id', '^users.id']]],
      where: [':and', [':=', ':id', 5], [':=', ':name', 'x']]
    }));
    return console.log(sql({
      update: "users",
      values: {
        a: 1,
        b: '^current_timestamp'
      },
      where: [':=', ':id', 5]
    }));
  };

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/bundle"] = {
  init:  function(){
    var exports = {};
    _current_file = "bundle";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  exports.history_bundle = function(resources) {
    return {
      resourceType: "Bundle",
      id: "???",
      total: resources.length,
      meta: {
        lastUpdated: new Date()
      },
      type: 'history',
      link: [
        {
          realtion: 'self',
          url: '???'
        }
      ],
      entry: resources.map(function(x) {
        return {
          fullUrl: '???',
          resource: x
        };
      })
    };
  };

  exports.search_bundle = function(query, resources) {
    return {
      resourceType: "Bundle",
      id: "???",
      total: resources.length,
      meta: {
        lastUpdated: new Date()
      },
      query: query,
      type: 'search',
      link: [
        {
          realtion: 'self',
          url: '???'
        }
      ],
      entry: resources.map(function(x) {
        return {
          fullUrl: '???',
          resource: x
        };
      })
    };
  };

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/schema"] = {
  init:  function(){
    var exports = {};
    _current_file = "schema";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  var namings, pg_meta, sql, utils;

  sql = require('../honey');

  namings = require('./namings');

  utils = require('./utils');

  pg_meta = require('./pg_meta');

  exports.create_table = function(plv8, resource_type) {
    var nm;
    nm = namings.table_name(plv8, resource_type);
    if (pg_meta.table_exists(plv8, nm)) {
      return {
        status: 'error',
        message: "Table " + nm + " already exists"
      };
    } else {
      utils.exec(plv8, {
        create: "table",
        name: nm,
        inherits: ['resource']
      });
      plv8.execute("ALTER TABLE " + nm + "\nADD PRIMARY KEY (id),\nALTER COLUMN created_at SET NOT NULL,\nALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP,\nALTER COLUMN updated_at SET NOT NULL,\nALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP,\nALTER COLUMN resource SET NOT NULL,\nALTER column resource_type SET DEFAULT '" + resource_type + "'");
      utils.exec(plv8, {
        create: "table",
        name: ['history', nm],
        inherits: ['history.resource']
      });
      plv8.execute("ALTER TABLE history." + nm + "\nADD PRIMARY KEY (version_id),\nALTER COLUMN valid_from SET NOT NULL,\nALTER COLUMN valid_to SET NOT NULL,\nALTER COLUMN resource SET NOT NULL,\nALTER column resource_type SET DEFAULT '" + resource_type + "'");
      return {
        status: 'ok',
        message: "Table " + nm + " was created"
      };
    }
  };

  exports.drop_table = function(plv8, nm) {
    nm = namings.table_name(plv8, nm);
    if (!pg_meta.table_exists(plv8, nm)) {
      return {
        status: 'error',
        message: "Table " + nm + " not exists"
      };
    } else {
      utils.exec(plv8, {
        drop: "table",
        name: nm,
        safe: true
      });
      utils.exec(plv8, {
        drop: "table",
        name: ['history', nm],
        safe: true
      });
      return {
        status: 'ok',
        message: "Table " + nm + " was dropped"
      };
    }
  };

  exports.describe_table = function(plv8, resource_type) {
    var columns, nm;
    nm = namings.table_name(plv8, resource_type);
    columns = utils.exec(plv8, {
      select: [':column_name', ':dtd_identifier'],
      from: ['information_schema.columns'],
      where: [':and', [':=', ':table_name', nm], [':=', ':table_schema', 'public']]
    });
    return {
      name: nm,
      columns: columns.reduce((function(acc, x) {
        acc[x.column_name] = x;
        delete x.column_name;
        return acc;
      }), {})
    };
  };

}).call(this);

    return module.exports;
  }
}
_modules["/root/fhirbase-plv8/src/core/search"] = {
  init:  function(){
    var exports = {};
    _current_file = "search";
    _current_dir = "/root/fhirbase-plv8/src/core";
    var module = {exports: exports};
    (function() {
  var bundle, comment, identity, isArray, mk_where, namings, selector, sql, table, utils;

  namings = require('./namings');

  bundle = require('./bundle');

  sql = require('../honey');

  utils = require('./utils');

  selector = function(path) {
    path;
    if (path.match(/^\.\./)) {
      return path.replace(/^\.\./, '');
    } else if (path.match(/^\./)) {
      return "resource#>>'{" + (path.replace(/^\./, '').replace(/\./g, ',')) + "}'";
    } else {
      throw new Error('unexpected selector .elem or ..elem');
    }
  };

  table = {
    contains: function(v) {
      return [':ilike', "%" + v + "%"];
    },
    startWith: function(v) {
      return [':ilike', v + "%"];
    },
    endWith: function(v) {
      return [':ilike', "%" + v];
    },
    "in": function(v) {
      return [':in', v];
    },
    between: function(v) {
      return [':between', v];
    }
  };

  isArray = function(value) {
    return value && typeof value === 'object' && value instanceof Array && typeof value.length === 'number' && typeof value.splice === 'function' && !(value.propertyIsEnumerable('length'));
  };

  mk_where = function(expr) {
    var op, path, ref, special_handler, v;
    if (isArray(expr)) {
      if (expr[0].toLowerCase() === 'and' || expr[0].toLowerCase() === 'or') {
        return [":" + (expr[0].toLowerCase())].concat(expr.slice(1).map(mk_where));
      } else {
        path = selector(expr[0]);
        op = expr[1];
        v = expr.slice(2);
        special_handler = table[op];
        if (special_handler) {
          ref = special_handler(v), op = ref[0], v = ref[1];
        } else {
          op = ":" + op;
          v = v[0];
        }
        return [op, "^" + path, v];
      }
    } else {
      return expr;
    }
  };

  identity = function(x) {
    return x;
  };

  exports.search_sql = function(plv8, query) {
    var q, table_name;
    table_name = namings.table_name(plv8, query.resourceType);
    q = {
      select: [':*'],
      from: [table_name]
    };
    q.where = mk_where(query.query);
    if (query.limit) {
      q.limit = query.limit;
    }
    if (query.offset) {
      q.offset = query.offset;
    }
    return q;
  };

  exports.search = function(plv8, query) {
    var q, res;
    q = exports.search_sql(plv8, query);
    res = utils.exec(plv8, q);
    res = res.map(function(x) {
      return JSON.parse(x.resource);
    });
    return bundle.search_bundle(query, res);
  };

  comment = function() {
    var q;
    q = {
      resourceType: 'Something',
      query: ['contains', 'name', 'som']
    };
    q = {
      resourceType: 'Something',
      limit: 100,
      offset: 5,
      query: ['and', ['.name', 'contains', 'som'], ['.contact.0.address', '=', 'something']]
    };
    return console.log(exports.search_sql(null, q));
  };

}).call(this);

    return module.exports;
  }
}
  // modules stop

  this.require = function(dep){
    var abs_path = dep.replace(/\.coffee$/, '');
    if(dep.match(/^\.\.\//)){
      var dir = _current_dir.split('/');
      dir.pop();
      abs_path = dir.join('/') + '/' + dep.replace('../','');
    }
    else if(dep.match(/^\.\//)){
      abs_path = _current_dir + '/' + dep.replace('./','');
    }
    // todo resolve paths
    var mod = _modules[abs_path]
    if(!mod){ throw new Error("No module " + abs_path + " while loading " + _current_dir + '/' + _current_file)}
    if(!mod.cached){ mod.cached = mod.init() }
    return mod.cached
  }
  this.modules = function(){
    var res = []
    for(var k in _modules){ res.push(k) }
    return res;
  }
  this.console = {
    log: function(x){ plv8.elog(NOTICE, x); }
  };
  return 'done'
$$ LANGUAGE plv8 IMMUTABLE STRICT;

CREATE SCHEMA IF NOT EXISTS core;
---
CREATE OR REPLACE FUNCTION
core.create(resource jsonb)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/core/crud.coffee")
  mod.create(plv8, resource)
$$ LANGUAGE plv8;
---
---
CREATE OR REPLACE FUNCTION
core.read(query jsonb)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/core/crud.coffee")
  mod.read(plv8, query)
$$ LANGUAGE plv8;
---
---
CREATE OR REPLACE FUNCTION
core.vread(query jsonb)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/core/crud.coffee")
  mod.vread(plv8, query)
$$ LANGUAGE plv8;
---
---
CREATE OR REPLACE FUNCTION
core.update(resource jsonb)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/core/crud.coffee")
  mod.update(plv8, resource)
$$ LANGUAGE plv8;
---
---
CREATE OR REPLACE FUNCTION
core.delete(resource jsonb)
RETURNS jsonb AS $$
  var mod = require("/root/fhirbase-plv8/src/core/crud.coffee")
  mod.delete(plv8, resource)
$$ LANGUAGE plv8;
---
