# Node devops course: Istio Chapter

## Setup inicial

### Minikube

Instale o Minikube no Mac:
```sh
brew install minikube
```
Instalação Linux: https://minikube.sigs.k8s.io/docs/start/


Para listar os contextos em que seu `kubectl` está conectado faça um:

```sh
kubectl config get-contexts
```

Se necessário mude o contexto para o Minikube:

```sh
kubectl config use-context minikube
```

### Istio

Baixe e descompacte o Istio 1.6.5 (precisa ser até essa versão pois a partir do release 1.7.0 o profile demo não vem mais com kiali e outras ferramentas apresentadas nesse workshop) que pode ser encontrado na url: https://istio.io/latest/news/releases/1.6.x/announcing-1.6.5/ (a partir da versão 1.7.0 o kiali e outros add-ons precisam ser instalados separadamente). Instale o Istio na versão do profile demo segundo a doc: https://istio.io/latest/docs/setup/getting-started/. Abaixo o tutorial resumido:

Resumindo o link acima, depois de baixar o Istio 1.6.5 e descompactá-lo:
```sh
cd istio-1.6.5
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo
```

Obs: No Linux uma alternativa bem interessante ao uso do `Minikube` é o `Microk8s` (https://microk8s.io). Entretando alguns dos add-ons utilizados nesse workshop precisarão ser instalados manualmente também. Espero poder atualizar esse material explicando como fazer esse setup em algum momento ;)

### Helm

Instale o Helm no Mac:
```sh
brew install helm
```
Instalação Linux: https://helm.sh/docs/intro/install/

### Namespace a ser usado nesse workshop

Crie o namespace `istio-dev` que vamos precisar nos exemplos:
Na pasta de nosso projeto execute:
```sh
kubectl apply -f temp/istio-namespace.json
```

## Hands-on!

### Se familiarizando com o worflow de trabalho desse workshop:

Criação/alteração das aplicações no cluster via helm

Para verificar o que o Helm vai aplicar no cluster:
```sh
./utils.sh install yaml
```
Observe que foi criado o arquivo `helm-generated.yaml` com o conteúdo a ser aplicado no cluster pelo Helm

Para realmente instalar nossas aplicações no cluster:
```sh
./utils.sh install
```

Você pode alterar os yamls de template do Helm e aplicar as mudanças usando esse passo

### Fazendo port forward e chamando cadeia de serviços:

Faça o port forward do ingress para que possamos fazer uma chamada a entrada de nossa aplicação:
```sh
./utils.sh pfIngress
```

Em outra abas faça uns requests para nossa cadeia de serviços (será necessário instalar em seu SO o `watch` e o `json_pp` caso já não possua)
```sh
./utils.sh callChain
```

Para fazer uma única chamada à aplicação use:
```sh
./utils.sh callChain single
```

Deixe essas abas rodando as chamadas ao cluster para que possamos ver como a aplicação está respondendo

### Acessando o Kiali e Jager para melhor entendimento do que está ocorrendo no cluster:

Em outra aba, verifique como o Kiali identificou a topologia de nossos serviços: (user e senha: admin)
```sh
./utils.sh kiali
```

Em outra aba, veja os tracings no Jaeger
```sh
./utils.sh jaeger
```
Mantenha o `Kiali` e o `Jaeger` rodando para que as consequências das alterações no cluster possam ficar visíveis

### Emulando uma instabilidade:

Vamos introduzir latência na aplicação para verificar o comportamento dela.

Escolha uma das aplicações (número de 1 a 5) para adicionar o endpoint de aumento de latência. No exemplo abaixo vamos escolher a instância `3` para fazer o port-forward:
```sh
./utils.sh pf 3
```
Obs: esse port-forward é para o Service e não do Pod, mas como só temos uma instância no deployment desse recurso teremos um comportament consistente. Caso fossem 2 instâncias seria introduzido delay em apenas uma delas.

Agora podemos chamar o endpoint de introdução de latência:
```sh
./utils.sh callDelay
```

Observe no navegador o `Jaeger` e procure pelo tracing das chamadas recentes feitas ao `callChain` que ainda deve estar rodando em uma aba do terminal

Vamos voltar para a situação instável e vamos fazer o revert do comportament de delay para introduzir um novo conceito no próximo step. Por agora faça uma nova chamada ao endpoint anterior:
```sh
./utils.sh callDelay
```

Observe pelo `Jaeger` ou `Kiali` que o sistema voltou a ficar estável. Deixe os terminais preparados para refazermos esse processo, mas antes aba uma nova aba para fazermos uma nova config no passo seguinte!

### Ligando o circuit breaker do Istio-Proxy/Sidecar:

Vamos fazer uma mudança na estrutura de nosso chart do helm, antes de aplicá-la vamos ver o atual estado de nossos charts. Repare na revision da saída do comando abaixo:
```sh
helm -n istio-dev list
```

Para ativar a configuração de circuit breaker nos Pods do cluster ligue a flag da seguinte variável de ambiente:
```sh
export ISTIO_CIRCUIT_BREAKER_ON=1
```

Vamos agora habilitar essa config fazendo nesse terminal o comando:
```sh
./utils.sh install
```

Caso esteja curioso com o que foi aplicado, execute o comando abaixo e observe no arquivo `healm-generated.yaml` nos recursos de `DestinationRule` principalmente
```sh
./utils.sh install yaml
```

Vamos repetir o processo de introduzir latência. Supondo que ainda existe um terminal rodandno com o `./utils.sh pf 3` onde `3` é um número de 1 a 5 de um dos serviços da cadeia de chamadas. Novamente faça a chamada:
```sh
./utils.sh callDelay
```

Repare o comportamento agora. Depois de algumas tentativas com timeout o nosso circuit breaker abre o circuito e a aplicação começa a retornar o JSON de fallback com uma chamada parcialmente completa.

### Canary Deploy:

Vamos agora testar o Canary subindo em uma das aplicações (primeiro argumento: 3) uma versão para a Green (segundo argumento: 0.2) com um certo percentual de tráfego (terceiro argumento: 0)
Para observar o que o Helm irá fazer no cluster:
```sh
./utils.sh enableGreen 3 0.2 0 yaml
```
Observe que foi criado o arquivo `helm-generated.yaml` com o conteúdo a ser aplicado no cluster pelo Helm

Para executar a instalação:
```sh
./utils.sh enableGreen 3 0.2 0
```

Agora que a Green está preparada vamos aumentar o percentual dela para 80%:

```sh
./utils.sh enableGreen 3 0.2 80
```

Observe o `Kiali` o grafo da aplicação sendo alterado