set -e
#CA
openssl genrsa -aes256 -out ca.key 4096
openssl req -key ca.key -new -x509 -days 3650 -sha256 -out ca.crt -subj '/DC=com/DC=mycompany/CN=MyRootCA'

#Backend
openssl req -out backend.csr -new -newkey rsa:2048 -nodes -keyout backend.key.pem -subj '/DC=com/DC=mycompany/CN=localhost'
openssl req -verify -in backend.csr -text -noout
openssl x509 -req -days 365 -in backend.csr -CA ca.crt -CAkey ca.key -out backend.crt.pem -sha256 -CAcreateserial 
openssl x509 -in backend.crt.pem -text

#Client
openssl req -out client.csr -new -newkey rsa:2048 -nodes -keyout client.key.pem -subj '/DC=com/DC=mycompany/CN=client'
openssl x509 -req -days 365 -in client.csr -CA ca.crt -CAkey ca.key -out client.crt.pem -sha256 -CAcreateserial
openssl x509 -in client.crt.pem -text

#Truststore
keytool -importcert -trustcacerts -file ca.crt -keystore truststore.jks

#Keystore
openssl pkcs12 -export -chain -in client.crt.pem -inkey client.key.pem -out keystore_chain.p12 -name client-cert -CAfile ca.crt
keytool -importkeystore -srckeystore keystore_chain.p12 -srcstoretype pkcs12 -destkeystore keystore_chain.jks -deststoretype jks
keytool -list -keystore kekeystore_chainystore.jks -v

#Keystore - changeit
openssl pkcs12 -export -chain -in client.crt.pem -inkey client.key.pem -out keystore_changeit.p12 -name client-cert -CAfile ca.crt
keytool -importkeystore -srckeystore keystore_changeit.p12 -srcstoretype pkcs12 -destkeystore /Users/bszeti/.sdkman/candidates/java/current/jre/lib/security/cacerts -deststoretype jks
keytool -list -keystore /Users/bszeti/.sdkman/candidates/java/current/jre/lib/security/cacerts -storepass changeit -v

# export JAVA_OPTS='-Djavax.net.ssl.trustStore=/Users/bszeti/projects/myproject/ssl/certs/truststore.jks -Djavax.net.ssl.trustStorePassword=secret -Djavax.net.ssl.keyStore=/Users/bszeti/projects/myproject/ssl/certs/keystore.p12 -Djavax.net.ssl.keyStorePassword=secret -Djavax.net.ssl.keyStoreType=pkcs12 -Djavax.net.debug=ssl,defaultctx,sslctx'
# export JAVA_OPTS='-Djavax.net.ssl.keyStore=/Users/bszeti/.sdkman/candidates/java/current/jre/lib/security/cacerts -Djavax.net.ssl.keyStorePassword=changeit -Djavax.net.debug=ssl -Djavax.net.debug=defaultctx,sslctx'
