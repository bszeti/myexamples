# CRDS=$(oc get crd -ojsonpath='{.items..metadata.name}') 
# CRDS=$(oc get crd  -ojsonpath='{range .items[?(@.spec.scope=="Namespaced")]}{.metadata.name}{"\n"}' ) 
CRDS=$(oc get crd  -ojsonpath='{range .items[?(@.spec.scope=="Namespaced")]}{.metadata.name}{"\n"}' | grep -v operators.coreos.com) 
NAMESPACE=my-terminating-namespace 
for crd in $CRDS  
do 
 # echo crd: $crd 
 oc get $crd -n $NAMESPACE -oname
done 