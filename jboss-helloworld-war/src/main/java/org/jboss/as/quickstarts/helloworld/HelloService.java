/*
 * JBoss, Home of Professional Open Source
 * Copyright 2015, Red Hat, Inc. and/or its affiliates, and individual
 * contributors by the @authors tag. See the copyright.txt in the
 * distribution for a full listing of individual contributors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.jboss.as.quickstarts.helloworld;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSessionContext;

import org.apache.http.HttpEntity;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.ssl.SSLContexts;
import org.apache.http.util.EntityUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class HelloService {
    private static final Logger log= LoggerFactory.getLogger(HelloService.class);

//    private CloseableHttpClient httpclient = HttpClients.createSystem();

    String createHelloMessage(String name) {
        log.info("Calling backend");
        log.info("javax.net.ssl.keyStore: {}",System.getProperty("javax.net.ssl.keyStore"));
        log.info("javax.net.ssl.keyStorePassword: {}",System.getProperty("javax.net.ssl.keyStorePassword"));
        log.info("javax.net.ssl.keyStoreType: {}",System.getProperty("javax.net.ssl.keyStoreType"));

//        SSLContexts sslContexts = SSLContexts.createDefault();
//        SSLContext sslContext = SSLContexts.createSystemDefault();

        CloseableHttpClient httpclient = HttpClients.createSystem();
//        CloseableHttpClient httpclient = HttpClients.createDefault();
//        DefaultHttpClient httpclient = new DefaultHttpClient();

        HttpGet getRequest = new HttpGet("https://localhost:4444/");

        try (CloseableHttpResponse httpResponse = httpclient.execute(getRequest)) {
            HttpEntity entity = httpResponse.getEntity();
            if (entity != null) {
                String body=EntityUtils.toString(entity);
                log.info("Backend: {}", body);
                return body;
            }
        } catch (Exception ex) {
            log.error("Backend error",ex);
        }
        return "Backend Error";
    }

}
