# xray-gw

Прозрачный шлюз Xray (TUN) для контейнеров MikroTik RouterOS 7.x (arm64/amd64).

- Xray-core v26.10.21 из официального релиза, контрольная сумма SHA-256 закреплена в Dockerfile.
- Alpine 3.22 + iproute2, iptables, curl — есть shell для диагностики.
- Трафик, пришедший на uplink контейнера, направляется в TUN `xray0` (таблица 100, правило `iif <uplink>`).
  Собственные соединения Xray к VPS идут через main. Без TUN транзит блокируется правилом `unreachable`.
- Секретов в образе нет: конфиг монтируется в `/etc/xray/config.json`.
- Пример конфига: `config.example.json` (балансировщик: основной `vless443`, при отказе — `vless2443`).

Запуск в RouterOS: см. инструкции проекта. Контейнер должен работать от root (`user=` пусто или `0:0`).
