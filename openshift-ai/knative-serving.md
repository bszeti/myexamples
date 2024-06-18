# Accessing a single model serving endpoint in Red Hat OpenShift AI

Let's take a look at the underlying K8s resources and traffic routing created by the platform for "single model serving".
Related docs: https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/2.9/html-single/serving_models/index#serving-large-models_serving-large-models

## External Route

Routes created automatically for the service:
- test-aiproject.apps.mycluster.example.com
- test-predictor-aiproject.apps.mycluster.example.com

```
curl https://test-aiproject.apps.mycluster.example.com/
curl https://test-predictor-aiproject.apps.mycluster.example.com/
```

```
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  namespace: istio-system
  name: test-aiproject
spec:
  host: test-aiproject.apps.mycluster.example.com
  to:
    kind: Service
    name: istio-ingressgateway
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  namespace: istio-system
  name: route-d403e035-1826-470f-9447-fb75e7082c99-616265633232
spec:
  host: test-predictor-aiproject.apps.mycluster.example.com
  to:
    kind: Service
    name: istio-ingressgateway
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
```

The _Routes_ point to _Service_ `istio-system/istio-ingressgateway:443` to enter the mesh (port 8443 on the gateway _Pod_):

```
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-system
  labels:
    app: istio-ingressgateway
    istio: ingressgateway
    knative: ingressgateway
    ...
spec:
  type: ClusterIP
  clusterIP: 172.31.25.181
  ports:
  - name: http2
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
  - name: status-port
    port: 15021
    targetPort: 15021
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
    knative: ingressgateway
```

Related _Gateway_ config:

```
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  namespace: knative-serving
  name: knative-ingress-gateway
spec:
  selector:
    knative: ingressgateway
  servers:
  - hosts:
    - '*.apps.mycluster.example.com'
    port:
      name: https
      number: 443
      protocol: HTTPS
    tls:
      credentialName: ingress-certs-2024-06-02
      mode: SIMPLE
```

VirtualService for `test-aiproject.apps.mycluster.example.com` - applied on the gateway - overwrites `Host` header to `test-predictor.aiproject.svc.cluster.local` and forwards to ingress-gateway via `knative-local-gateway.istio-system.svc`:

```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  namespace: aiproject
  name: test
spec:
  gateways:
  - knative-serving/knative-local-gateway
  - knative-serving/knative-ingress-gateway
  hosts:
  - test.aiproject.svc.cluster.local
  - test-aiproject.apps.mycluster.example.com
  http:
  - headers:
      request:
        set:
          Host: test-predictor.aiproject.svc.cluster.local
    match:
    - authority:
        regex: ^test\.aiproject(\.svc(\.cluster\.local)?)?(?::\d{1,5})?$
      gateways:
      - knative-serving/knative-local-gateway
    - authority:
        regex: ^test-aiproject\.apps\.cluster-vwtg7\.dynamic\.redhatworkshops\.io(?::\d{1,5})?$
      gateways:
      - knative-serving/knative-ingress-gateway
    route:
    - destination:
        host: knative-local-gateway.istio-system.svc.cluster.local
        port:
          number: 80
...
```

`knative-local-gateway.istio-system.svc.cluster.local:80` is hitting the ingress-gateway _Pod_ on port 8081

```
apiVersion: v1
kind: Service
metadata:
  namespace: istio-system
  name: knative-local-gateway
spec:
  type: ClusterIP
  clusterIP: 172.31.71.187
  ports:
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 8081
  selector:
    knative: ingressgateway
```

```
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  namespace: knative-serving
  name: knative-local-gateway
spec:
  selector:
    knative: ingressgateway
  servers:
  - hosts:
    - '*.svc.cluster.local'
    port:
      name: https
      number: 8081
      protocol: HTTPS
    tls:
      mode: ISTIO_MUTUAL
```

Routing to `test-predictor.aiproject.svc.cluster.local` on the ingress-gateway to `test-predictor-00001.aiproject.svc.cluster.local:80` due to this _VirtualService_:

```
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  namespace: aiproject
  name: test-predictor-ingress
spec:
  gateways:
  - knative-serving/knative-ingress-gateway
  - knative-serving/knative-local-gateway
  hosts:
  - test-predictor-aiproject.apps.mycluster.example.com
  - test-predictor.aiproject
  - test-predictor.aiproject.svc
  - test-predictor.aiproject.svc.cluster.local
http:
  - match:
    - authority:
        prefix: test-predictor-aiproject.apps.mycluster.example.com
      gateways:
      - knative-serving/knative-ingress-gateway
    route:
    - destination:
        host: test-predictor-00001.aiproject.svc.cluster.local
        port:
          number: 80
  - match:
    - authority:
        prefix: test-predictor.aiproject
      gateways:
      - knative-serving/knative-local-gateway
    route:
    - destination:
        host: test-predictor-00001.aiproject.svc.cluster.local
        port:
          number: 80
...
```

```
apiVersion: v1
kind: Service
metadata:
  name: test-predictor-00001
  namespace: aiproject
spec:
  type: ClusterIP
  clusterIP: 172.31.73.205
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8012
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8112
```

Traffic reaches `knative-activator:8012`, then it's routed to `test-predictor-00001-private.aiproject.svc.cluster.local:80` (IP 172.31.58.48 below), hitting the final _Pod_ on port 8012.

Enable istio-proxy access log (in _ServiceMeshControlPlane_ `proxy.accessLogging.file.name: /dev/stdout`) to follow routing:

Ingress-gateway (10.135.0.43) access log:
```
GET / HTTP/2" 400 - via_upstream - "-" 0 32 26 24 "10.134.0.2" "
    curl/8.6.0" "4791d0d3-e742-4eac-8c56-4c87eb22f1a9" "test-predictor.aiproject.svc.cluster.local" "10.135.0.43:8081" outbound|80
    ||knative-local-gateway.istio-system.svc.cluster.local 10.135.0.43:39352 10.135.0.43:8443 10.134.0.2:56558 test-aiproject.apps.mycluster.example.com -
GET / HTTP/2" 400 - via_upstream - "-" 0 32 20 20 "10.134.0.2,10.135.0.43" 
    "curl/8.6.0" "f7beed8d-a4db-4aaa-9292-edbf3e186e29" "test-predictor.aiproject.svc.cluster.local" "10.135.0.44:8012" outbound|80
    ||test-predictor-00001.aiproject.svc.cluster.local 10.135.0.43:45990 10.135.0.43:8081 10.135.0.43:39352 outbound_.80_._.knative-local-gateway.istio-system.svc.cluster.local -
```

Knative-serving activator (10.135.0.44) access log:
```
"GET / HTTP/1.1" 400 - via_upstream - "-" 0 32 13 13 "10.134.0.2,10.135.0.43" 
    "curl/8.6.0" "f7beed8d-a4db-4aaa-9292-edbf3e186e29" "test-predictor.aiproject.svc.cluster.local" "10.135.0.44:8012" inbound|8012
    || 127.0.0.6:40375 10.135.0.44:8012 10.135.0.43:0 outbound_.80_._.test-predictor-00001.aiproject.svc.cluster.local default
"GET / HTTP/1.1" 400 - via_upstream - "-" 0 32 12 11 "10.134.0.2,10.135.0.43, 127.0.0.6" 
    "curl/8.6.0" "f7beed8d-a4db-4aaa-9292-edbf3e186e29" "172.31.58.48:80" "10.133.2.13:8012" outbound|80
    ||test-predictor-00001-private.aiproject.svc.cluster.local 10.135.0.44:50332 172.31.58.48:80 127.0.0.6:0 - default
```

Model Pod `test-predictor-00001-deployment...` port 8012 (10.133.2.13):
```
"GET / HTTP/1.1" 400 - via_upstream - "-" 0 32 4 3 "10.134.0.2,10.135.0.43, 127.0.0.6" 
    "curl/8.6.0" "f7beed8d-a4db-4aaa-9292-edbf3e186e29" "172.31.58.48:80" "10.133.2.13:8012" inbound|8012
    || 127.0.0.6:45919 10.133.2.13:8012 127.0.0.6:0 outbound_.80_._.test-predictor-00001-private.aiproject.svc.cluster.local default
```

**_NOTE:_** Hitting route `test-predictor-aiproject.apps.mycluster.example.com` results only one access log in the ingress-gateway.

## Access service from a Pod inside the mesh

Related _Services_:
- `test.aiproject.svc.cluster.local`: Doesn't seem to work. _TODO: What is this service for?_
- `test-predictor.aiproject.svc.cluster.local`: This hostname works from a Pod within the mesh.

```
curl http://test-predictor.aiproject.svc.cluster.local
```
The `test-predictor-mesh` _VirtualService_ routes the traffic to `test-predictor-00001.aiproject.svc.cluster.local:80`

```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  namespace: aiproject
  name: test-predictor-mesh
spec:
  gateways:
  - mesh
  hosts:
  - test-predictor.aiproject
  - test-predictor.aiproject.svc
  - test-predictor.aiproject.svc.cluster.local
  http:
  - match:
    - authority:
        prefix: test-predictor.aiproject
      gateways:
      - mesh
    route:
    - destination:
        host: test-predictor-00001.aiproject.svc.cluster.local
        port:
          number: 80
...
```

To make `test.aiproject.svc.cluster.local` work from a Pod in  the mesh we need to create an additional _VirtualService_:
```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  namespace: aiproject
  name: test-mesh
spec:
  gateways:
  - mesh
  hosts:
  - test.aiproject
  - test.aiproject.svc
  - test.aiproject.svc.cluster.local
  http:
  - route:
    - destination:
        host: test-predictor.aiproject.svc.cluster.local
        port:
          number: 80
```

## Access service from a Pod outside the mesh

Using the Route hostnames work, but internal service hostnames do not. https://issues.redhat.com/browse/RHOAISTRAT-182

The Knative gateways created by OpenShift AI are configured with `ISTIO_MUTUAL` tls (port 443, 8081). To enable incoming http traffic from Pods outside the mesh, we need to create a new _Gateway_. Let's use port 8080, because that port is already set - but not used - in _Service_ `istio-system/ingressgateway`. We can create a _Gateway_ allowing HTTP port 8080 like this:

```
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  namespace: knative-serving
  name: knative-http-gateway
spec:
  selector:
    knative: ingressgateway
  servers:
  - hosts:
    - '*.svc.cluster.local'
    - '*.apps.mycluster.example.com'
    port:
      name: http
      number: 8080
      protocol: HTTP
```

Optionally we can also create a _Gateway_ limiting the scope of hostnames to our _DataScienceCluster_ project (or service):
```
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  namespace: aiproject
  name: knative-http-gateway
spec:
  selector:
    knative: ingressgateway
  servers:
  - hosts:
    - '*.aiproject.svc.cluster.local'
    - '*.apps.mycluster.example.com'
    # - test-http.aiproject.svc.cluster.local
    # - test-http-aiproject.apps.mycluster.example.com
    port:
      name: http
      number: 8080
      protocol: HTTP
```

**_NOTE:_**  Partial wildcard pattern is not allowed, so for external route hosts we set the usual wildcard pattern. This should not cause a problem even with multiple _DataScienceClusters_.

Then we need to create a _Service_ routing the traffic to the mesh's ingress-gateway:

```
apiVersion: v1
kind: Service
metadata:
  namespace: aiproject
  name: test-http
spec:
  externalName: istio-ingressgateway.istio-system.svc.cluster.local
  sessionAffinity: None
  type: ExternalName
```

In a matching VirtualService - applied on the new gateway - we need to forward traffic to the existing "predictor" _Service_.
```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  namespace: aiproject
  name: test-knative-http-gateway
spec:
  gateways:
  - knative-serving/knative-http-gateway
  hosts:
  - test-http.aiproject.svc.cluster.local
  - test-http-aiproject.apps.mycluster.example.com
  http:
  - headers:
      request:
        set:
          Host: test-predictor.aiproject.svc.cluster.local
    route:
    - destination:
        host: test-predictor.aiproject.svc.cluster.local
        port:
          number: 80
```

**_NOTE:_**  Use fully qualified hostnames only `*.svc.cluster.local` to avoid unexpected issues.

Check that the new gateway rules are picked up:

```
$ istioctl proxy-config routes -n istio-system istio-ingressgateway-64694db8d5-zmcc
NAME       VHOST NAME                                                    DOMAINS                                                                                                  MATCH  VIRTUAL SERVICE
http.8080  test-http-single-model-serve.apps.mycluster.example.com:8080  test-http-single-model-serve.apps.mycluster.example.com, test-http.single-model-serve.svc.cluster.local  /*     test-http.single-model-serve
```

From a Pod outside the mesh:
```
curl http://test-http.aiproject.svc.cluster.local:80
```

To expose service via http and edge TLS:

```
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  namespace: istio-system
  name: test-http-aiproject
spec:
  host: test-http-aiproject.apps.mycluster.example.com
  to:
    kind: Service
    name: istio-ingressgateway
  port:
    targetPort: 8080
  tls:
    insecureEdgeTerminationPolicy: Allow
    termination: edge
```

From outside the cluster:
```
curl http://test-http-aiproject.apps.mycluster.example.com/
curl https://test-http-aiproject.apps.mycluster.example.com/
```

## Accessing external services from a Pod in the mesh

Let's check outgoing connections to a non-mesh K8s _Service_ endpoint from a Pod in the mesh.

The _DataScienceCluster_ creates _ServiceMeshControlPlane_ `istio-system/data-science-smcp` with `spec.security.dataPlane.mtls: true`, that creates a default _PeerAuthentication_ with `spec.mtls.mode: STRICT`. Also the default value in _ServiceMeshControlPlane_ is `spec.proxy.networking.trafficControl.outbound: ALLOW_ANY`.

With `STRICT` mtls: 
- Outgoing connections to non-mesh services in the same namespace are blocked.
- Outgoing connections to non-mesh services in another namespace are allowed.

**_NOTE:_**  Make sure that a _NetworkPolicy_ allows inbound connections in the other namespace. Service Mesh enables only traffic between mesh member namespaces automatically (see _ServiceMeshMemberRoll_).

Setting `PERMISSIVE` mtls solves the problem of outgoing connections, but it also allows incoming http connections to the mesh services, which is not recommended. Services in the same namespace are blocked due to the default _DestinationRule_ - with `trafficPolicy.tls.mode: ISTIO_MUTUAL` - being set automatically in `istio-proxy` for service hostnames in the same namespace.

```
$ istioctl proxy-config clusters test-predictor-00001-deployment-bfc57c85b-ns2vj
SERVICE FQDN                                    PORT      SUBSET     DIRECTION     TYPE      DESTINATION RULE
no-mesh-service.aiproject.svc.cluster.local     8000      -          outbound      EDS       default.istio-system
```

```
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default
  namespace: istio-system
spec:
  host: '*.cluster.local'
  trafficPolicy:
    tls:
      tls: ISTIO_MUTUAL
```

To make outgoing connection work in `STRICT` mode for a _Service_ within the same namespace we need to create a _DestinationRule_ (and optionally a matching _VirtualService_).

```
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  namespace: aiproject
  name: non-mesh
spec:
  # host: non-mesh.aiproject.svc.cluster.local
  host: non-mesh
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  namespace: aiproject
  name: non-mesh
spec:
  gateways:
  - mesh
  hosts:
  - non-mesh
  - non-mesh.aiproject.svc
  - non-mesh.aiproject.svc.cluster.local
  http:
  - route:
    - destination:
        host: non-mesh
        port:
          number: 8000
```