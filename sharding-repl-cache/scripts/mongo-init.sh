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

docker compose exec -T shard1_1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1_1:27018" },
        { _id : 1, host : "shard1_2:27028" },
        { _id : 2, host : "shard1_3:27038" },
      ]
    }
)
EOF

###
# Инициализируем шард2
###
echo "Инициализируем шард2"

docker compose exec -T shard2_1 mongosh --port 27019 --quiet <<EOF

rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2_1:27019" },
        { _id : 1, host : "shard2_2:27029" },
        { _id : 2, host : "shard2_3:27039" },
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
sh.addShard( "shard1/shard1_1:27018,shard1_2:27028,shard1_3:27038");
sh.addShard( "shard2/shard2_1:27019,shard2_2:27029,shard2_3:27039");
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

###
# Проверка статуса replica sets
###
echo ""
echo "=== Статус shard1 ==="
docker compose exec -T shard1_1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " - " + m.stateStr))
EOF

echo ""
echo "=== Статус shard2 ==="
docker compose exec -T shard2_1 mongosh --port 27019 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " - " + m.stateStr))
EOF