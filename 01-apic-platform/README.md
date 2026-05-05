# APIC Platform (Namespaced)
oc apply -k 01-apic-platform/overlays/apic-lab
oc get managementcluster -n apic-lab

oc describe managementcluster management -n apic-lab
oc logs -n openshift-operators deployment/ibm-apiconnect -f
oc get events -n apic-lab --sort-by=.metadata.creationTimestamp

oc logs -n openshift-operators deployment/ibm-apiconnect -f \
  | egrep -i "apic-lab|management|reconcil|error|ready"

#Especifico apic-lab
oc logs -n openshift-operators deployment/ibm-apiconnect -f \
  | grep '"namespace":"apic-lab"'
``

#Pegar so erro
oc logs -n openshift-operators deployment/ibm-apiconnect --since=10m \
  | egrep -i "error|fail|panic|apic-lab"


oc get jobs

oc get events -n apic-lab
oc get pods -n apic-lab
oc get pvc -n apic-lab

#Configurar o selfsigning-issuer
oc get issuer selfsigning-issuer -n tools -o yaml


admin/Jk0r8iVp12GB
manager@2026
Mesmo colocando a secret para nao pedir para trocar ele solicita a troca da senha



START_TS=$(date +%s)
START_HUMAN=$(date +"%H:%M")

echo ">>> Monitorando ManagementCluster (namespace: apic-lab)"
echo ">>> Início em: $START_HUMAN"
echo

while true; do
  LINE=$(oc get managementcluster management -n apic-lab --no-headers)
  NOW_HUMAN=$(date +"%H:%M")

  READY=$(echo "$LINE" | awk '{print $2}')
  STATUS=$(echo "$LINE" | awk '{print $3}')

  echo "[$NOW_HUMAN] READY=$READY STATUS=$STATUS"

  if [ "$STATUS" != "Pending" ]; then
    END_TS=$(date +%s)
    END_HUMAN=$(date +"%H:%M")

    ELAPSED_SEC=$((END_TS - START_TS))
    ELAPSED_MIN=$((ELAPSED_SEC / 60))
    ELAPSED_H=$((ELAPSED_MIN / 60))
    ELAPSED_M=$((ELAPSED_MIN % 60))

    echo
    echo "✅ Status final atingido!"
    echo "   Início : $START_HUMAN"
    echo "   Fim    : $END_HUMAN"
    printf "   Duração: %02dh:%02dm\n" "$ELAPSED_H" "$ELAPSED_M"
    echo
    oc get managementcluster -n apic-lab
    break
  fi

  sleep 600
done



oc get secret admin-secret -n tools -o yaml > admin-secret.yaml
oc get secret gateway-peering -n tools -o yaml > gateway-peering.yaml
oc get secret gateway-service -n tools -o yaml > gateway-service.yaml

Servicos configurados (Topologia)
Data Power 

Management terminal in the gateway service
https://rgwd.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com

API endpoint base 
Você colocou:
https://rgw.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com

Analytic

https://ai.apiclab.apps.itz-h4eig5.infra01-lb.lon04.techzone.ibm.com

No API Dentro do Sandbox
Associar o Gateway

Dentro do Cloud Manager
Criado uma organizacao e definido a senha.

Depois que criar o analytic config tem que Clicar no Gateway e associar o analytic que vai capturar as informacoes


  mgmtPlatformEndpointCASecret:
    secretName: ingress-ca