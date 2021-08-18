set -e

docker build --progress tty -t httpd-ssl .

# docker run -it -p8443:8443 --entrypoint /bin/sh httpd-ssl
# docker run -it -p8443:8443 --entrypoint /bin/sh httpd-ssl -c "cat /tmp/assemble.log"
# exit

ID=$(docker run -d -p4443:8443 -p4444:8444 httpd-ssl)
echo $ID
sleep 3
curl -vvv --cacert /Users/bszeti/projects/myproject/ssl/certs/ca.crt https://localhost:4443
curl -vvv --cacert /Users/bszeti/projects/myproject/ssl/certs/ca.crt --key /Users/bszeti/projects/myproject/ssl/certs/client.key.pem --key-type PEM --cert /Users/bszeti/projects/myproject/ssl/certs/client.crt.pem https://localhost:4444

docker container logs $ID
docker attach  $ID