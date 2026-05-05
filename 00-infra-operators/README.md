# Infra Operators (Cluster Scope)
oc delete -k 00-infra-operators/

oc apply -k 00-infra-operators/
echo -n 'cp:eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJQk0gTWFya2V0cGxhY2UiLCJpYXQiOjE3NzUwMTE4NjgsImp0aSI6ImI5MjE3YzJlZTUyZjQxMmViOWYzMWRmNTMzYjAwODg4In0.JCJkhF-Ehrs1JpwUUCg627R1kjcv4PAPujeG4lfMQvU' | base64


oc apply -k 00-infra-operators/

oc get subscription -n apic-operator

oc delete catalogsources -n openshift-marketplace ibm-apiconnect-catalog 
oc delete catalogsources -n openshift-marketplace ibm-datapower-operator-catalog 

oc get catalogsources -n openshift-marketplace