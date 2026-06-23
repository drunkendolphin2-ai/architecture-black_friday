#!/bin/bash

###
# Инициализируем сервер конфигурации
###
echo "Инициализируем сервер конфигурации"

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
})
EOF

###
# Инициализируем шард1
###
echo "Инициализируем шард1"

docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1:27018" },
      ]
    }
)
EOF

###
# Инициализируем шард2
###
echo "Инициализируем шард2"

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF

rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 1, host : "shard2:27019" }
      ]
    }
  )
EOF

echo "Ожидание выбора primary"
sleep 20

###
# Инициализируем роутер и наполняем данными
###
echo "Инициализируем роутер и наполняем данными"

docker compose exec -T mongos1 mongosh --port 27020 --quiet <<EOF
sh.addShard( "shard1/shard1:27018");
sh.addShard( "shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i})
db.helloDoc.countDocuments()
EOF

###
# Проверка распределения по шардам
###
echo "Проверка распределения по шардам"

docker compose exec -T mongos1 mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.getShardDistribution()
EOF
