# MetalLB

MetalLB can be used to expose a Kubernetes service on a dedicated IP address. The IP address must be on the same subnet as the nodes. the IP will be advertised by the operator on one of the nodes.

MetalLB operator in OpenShift doc:

https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/networking_operators/index#metallb-operator


After installing the MetalLB operator, create a `MetalLB` to enable to operator in Layer 2 mode:
```yaml
apiVersion: metallb.io/v1beta1
kind: MetalLB
metadata:
  name: metallb
  namespace: metallb-system
```

## IP address pool

Create an `IPAddressPool` with the IP range for the services.

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: vlan-50-pool
spec:
  addresses:
  - 10.0.50.2-10.0.50.254
  # If we don't want IPs to be automatically assign to any LoadBalancer service
  autoAssign: false
```

Advertise the IP pool on the `br-ex` bridge that has the interface with the right VLAN on the nodes and also includes the internal ovs-bridge.

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: vlan50-advertise
  namespace: metallb-system
spec:
  ipAddressPools:
  - vlan-50-pool
  # Use br-ex bridge because that also has the internal OpenShift addresses
  interfaces:
  - br-ex
```

## Network config

Cluster-admins can assign any `externalIP` to a Service, but otherwise the network range should be enabled in OpenShift network config:

```yaml
apiVersion: config.openshift.io/v1
kind: Network
metadata:
  name: cluster
spec:
  ...
  externalIP:
    policy:
      allowedCIDRs:
      - 10.0.50.0/24
```

## Service

Assign IP to service with `metallb.io/loadBalancerIPs` annotation:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-metallb
  namespace: myproject
  annotations:
    metallb.io/loadBalancerIPs: 10.0.50.2
spec:
  type: LoadBalancer
  ...
```