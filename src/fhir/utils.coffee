uuid = (plv8)->
  plv8.execute('select gen_random_uuid() as uuid')[0].uuid

exports.uuid = uuid
