set -e
mvn clean package
cp target/*.war /Users/bszeti/projects/myproject/tools/jboss-eap-7.2/standalone/deployments/

sleep 10

curl -vvv http://localhost:8080/helloworld/HelloWorld