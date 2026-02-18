oc new-project fileserver
oc apply -n fileserver -f nginx-conf.yaml
oc apply -n fileserver -f service.yaml
oc apply -n fileserver -f route.yaml
oc apply -n fileserver -f pvc.yaml
oc apply -n fileserver -f deployment.yaml
# Copy files to PVC
oc rsync -n fileserver ./ $(oc get pod -n fileserver -oname):/opt/app-root/src
oc cp -n fileserver ./hello.txt $(oc get pod -n fileserver --no-headers -o custom-columns=:metadata.name):/opt/app-root/src/