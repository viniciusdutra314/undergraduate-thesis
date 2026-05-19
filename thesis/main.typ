#import "tcc_template.typ": tcc_generate_cover
#import "@preview/wordometer:0.1.5": *
#import "@preview/diagraph:0.3.7"
#import "@preview/subpar:0.2.2"
#import "@preview/zero:0.6.1": num, set-group, set-round

#set-round(
  mode: "uncertainty",
  precision: 1,
  pad: false,
  direction: "nearest",
  ties: "away-from-zero",
)

#set table(
  stroke: none,
  fill: (x, y) => if y == 0 { aqua.lighten(50%) } else if calc.even(y) { gray.lighten(70%) } else { gray.lighten(95%) },
)


#{
  if sys.version != version(0, 14, 2) {
    panic("O documento foi feito em Typst 0.14.2, talvez não funcione em outra versão")
  }
}
#show: tcc_generate_cover.with()


#heading("RESUMO", numbering: none) <text:introducao>



#let resumo_conteudo = par[
]


//invariantes sobre a seção de resumo
#word-count(wc => {
  assert(wc.words < 500, message: "Resumo com mais de 500 palavras")
  assert(resumo_conteudo.func() == par, message: "Resumo deve ser somente um paragráfo")
  let resumo_verificado = {
    show math.equation: it => panic("O resumo não deve conter equações matemáticas.")
    show cite: it => panic("O resumo não deve conter citações.")
    show ref: it => panic("O resumo não deve conter referências")

    resumo_conteudo
  }
  resumo_verificado
})



Palavras-chave: Redes complexas. Teoria de Grafos. Otimização.




= INTRODUÇÃO
A análise de redes complexas viabiliza a modelagem de sistemas heterogêneos sob a fundamentação matemática da teoria dos grafos. As aplicações abrangem desde o planejamento urbano e o estudo de tráfego baseados em grafos geométricos @boeingModelingAnalyzingUrban2025, até a computação quântica @javadi-abhariQuantumComputingQiskit2024, na otimização do mapeamento de algoritmos em circuitos físicos.

O presente trabalho realiza simulações de tráfego em redes complexas, com o objetivo de investigar e propor estratégias de otimização no fluxo de pacotes para diversas topologias e protocolos de roteamento. Essa otimização é feita por meio da modificação da capacidade de transmissão dos elos da rede, com o intuito de maximizar a taxa crítica de geração de pacotes ($rho_c$) e minimizar o atraso dos pacotes.

- *Simulador:* Implementar e validar um simulador de tráfego de pacotes de alto desempenho, capaz de modelar o envio de mensagens, filas de espera e diferentes estratégias de roteamento em grafos de média escala.
- *Alocação de Capacidade:* Propor e testar heurísticas para a distribuição não uniforme das capacidades de transmissão ($C$) entre as arestas, visando a minimização da  capacidade total da rede, avaliando como essa adaptação afeta o Atraso Médio ($delta$) e a geração crítica de mensagens $(rho_c)$.
- *Avaliação de Estratégias de Roteamento:* Comparar a eficiência das adaptações de capacidade propostas quando submetidas a diferentes algoritmos de roteamento, como Caminho Mínimo (_Shortest Path_) e estratégias de Visibilidade Limitada.
- *Análise Topológica:* Investigar a relação entre métricas topológicas, como a Centralidade de Intermediação de Aresta ($b_e$)  e o tráfego resultante em diferentes redes como Erdos-Rényi, Barabási-Albert, redes em grade, etc.


= Tráfego de pacotes em redes complexas

== Tipos de grafos

#let definição_grafo = [
  Embora existam variações terminológicas  na literatura, define-se um grafo $G$ como um par ordenado $G = (V, E)$, onde $V$ representa um conjunto finito e não vazio de elementos denominados *vértices*, enquanto $E$ consiste em um conjunto de pares não ordenados de elementos pertencentes a $V$, denominados *arestas* @trudeauIntroductionGraphTheory1993.
]
#definição_grafo

#let definição_digrafo = [
  Um *grafo dirigido*, ou simplesmente *dígrafo*, caracteriza-se por um conjunto $E$ composto por pares ordenados de vértices de $V$. Diferente dos grafos não direcionados, a relação de adjacência em um dígrafo implica que $(u, v) != (v, u)$, estabelecendo uma orientação específica para a conexão entre os nós.
]
#definição_digrafo

#let definição_grafo_ponderado = [
  Um *grafo ponderado* é definido pela associação de uma função peso $w: E -> RR$, que atribui a cada aresta um valor escalar real. No contexto de tráfego, tal grandeza frequentemente representa o custo, a capacidade ou a "intensidade" da conexão entre dois pontos.
]

#definição_grafo_ponderado

Neste trabalho, salvo indicação contrária, o termo "grafo" se refere a um grafo não direcionado e não ponderado. Quaisquer variações a essa definição padrão serão explicitamente detalhadas no decorrer do texto.

== Propriedades de um grafo

Dois vértices $u, v in V$ são ditos *adjacentes* se existir uma aresta ${u, v} in E$. O vértice $v$ é denominado *vizinho* de $u$, e vice-versa. O conjunto de todos os vértices adjacentes a um vértice $v$ define a sua *vizinhança*, denotada por $N_G (v)$. A cardinalidade deste conjunto, que representa o número de arestas incidentes ao vértice, define o seu *grau*, denotado por $deg(v)$.


Um *caminho* entre dois vértices $s, t in V$ é definido como uma sequência de vértices $P = (v_0, v_1, ..., v_k)$ tal que $v_0 = s$, $v_k = t$, e para todo $i$ tal que $0 <= i < k$  ${v_i, v_{i+1}} in E$. O *comprimento* do caminho é dado por $k$, que corresponde ao número de arestas na sequência. É importante notar que tal caminho pode não existir; nesse caso, diz-se que $t$ é inatingível a partir de $s$. Um grafo é dito *conexo* se, para todo par de vértices, existe pelo menos um caminho que os conecta, caso contrário, o grafo é classificado como *desconexo*.

Um *caminho mínimo* entre dois vértices $s$ e $t$ é um caminho cujo comprimento $k$ é o menor possível dentre todos os caminhos existentes entre esses vértices. Ressalta-se que o caminho mínimo não é necessariamente único.  A *distância* entre $s$ e $t$, denotada por $d_(s t)$, é definida como o comprimento desse caminho mínimo. Convenciona-se que, caso não exista caminho entre $s$ e $t$, $d(s, t) = infinity$.
#footnote[Em implementações computacionais, sistemas que utilizam a representação de ponto flutuante segundo o padrão IEEE 754
  @IEEEStandardFloatingPoint2019 possuem uma representação de infinito com propriedades desejáveis para vértices inatingíveis.]

A partir da definição de caminhos mínimos, derivam-se duas métricas topológicas fundamentais para a caracterização do modelo de tráfego. A primeira é a *distância média* $chevron.l L chevron.r$, que representa o valor esperado do comprimento do caminho mínimo entre dois vértices quaisquer da rede.

$ chevron.l L chevron.r := 1 / (|V|(|V|-1)) sum_(i != j) d_(i j) $

A segunda métrica é a *Centralidade de Intermediação de Aresta* (_Edge Betweenness Centrality_) @brandesVariantsShortestpathBetweenness2008a, que quantifica a frequência em que uma aresta é visitada por caminhos mínimos. A centralidade de intermediação da aresta $e$, denotada por $b_e$, é definida como a soma das frações de todos os caminhos mínimos da rede que passam por essa aresta, normalizada pelo número de arestas possíveis:

$ b_e = 1 / (|V|(|V|-1)) sum_(s, t in V) (sigma(s, t | e)) / (sigma(s, t)) $

Seja $cal(W)_(s t)$ o conjunto de todos os caminhos mínimos de um vértice origem $s$ até um destino $t$. Definimos o escalar $sigma(s, t) := |cal(W)_(s t)|$ como a cardinalidade deste conjunto, isto é, o número total de caminhos mínimos possíveis entre $s$ e $t$. Para uma dada aresta $e in E$, denotamos por $sigma(s, t | e)$ a quantidade desses caminhos mínimos que passam  por $e$.



A definição de $b_e$ foi escolhida com o fator de normalização para que uma relação ficasse mais simples, conforme demonstrado por @brandesMaintainingDualityCloseness2016, a soma das centralidades de intermediação de todas as arestas de um grafo é igual a distância média. Esse resultado é importante para analisar como a topologia da rede influencia o tráfego de pacotes


$ chevron.l L chevron.r = sum_(e in E) b_e $ <eq:sum_edge_betweeness>



Modelos de trafego

tipos de otimização possíveis

políticas de filas

Roteamento dinamicos






= MATERIAIS E MÉTODOS


Dada a elevada combinatória de dinâmicas em grafos de médio porte ($|V| approx 10^3$), o simulador foi desenvolvido na linguagem Rust visando assegurar a viabilidade computacional das simulações em hardware convencional. Esta escolha fundamenta-se na necessidade de conciliar o desempenho de uma linguagem compilada a garantias rigorosas de segurança de memória, concorrência sem condições de corrida e corretude dos resultados @jungRustBeltSecuringFoundations2017. A implementação atual permite a execução paralela de simulações em redes compostas por milhares de nós, utilizando a biblioteca de alto desempenho #text(style: "italic")[rustworkx_core]
@treinishRustworkxHighPerformanceGraph2022 para a manipulação eficiente de algoritmos e estruturas de dados.

Visando assegurar a reprodutibilidade das simulações e resultados apresentados,
o código fonte do simulador foi disponibilizado em um repositório público no
GitHub, acessível pelo endereço #link("https://github.com/viniciusdutra314/GraphTraffic-rs").
O projeto está sob a licença permissiva MIT, viabilizando sua utilização,
modificação e distribuição em diferentes contextos.


A verificação de corretude do simulador foi realizada por meio de uma bateria sistemática de testes unitários e de integração, como métrica quantitativa de qualidade de software, utilizou-se a ferramenta `llvm-cov` para mapear a cobertura de testes do código das mais de duas mil linhas que constituem o núcleo do simulador. Conforme ilustrado na @fig:table_llvm_cov, o conjunto de testes alcançou uma cobertura global de aproximadamente 95%, reduzindo a probabilidade de _bugs_ e aumentando a segurança dos resultados obtidos.

#figure(
  image("assets/tables/llvm_cov_table.png", width: 75%),
  caption: [Cobertura de testes do simulador],
) <fig:table_llvm_cov>

Os gráficos e as análises dos dados foram realizadas na linguagem de alto nível Julia @bezansonJuliaFreshApproach2017 com o usado da biblioteca Makie
@danischMakiejlFlexibleHighperformance2021, oferecendo um equilíbrio entre agilidade, exploração interativa e desempenho

== Formalização do modelo de tráfego de pacotes <sec:formalização_modelo_trafego>

Baseado na meta-análise de
#cite(<chenTrafficDynamicsComplex2012>, form: "prose"), utilize-se um modelo de trafego simples porém usual em artigos de trafego de pacotes, o sistema é descrito por um grafo e um conjunto de regras dinâmicas de geração e roteamento de informação.


Seja $G = (V, E)$ um grafo conexo, não direcionado, onde $V$ representa o conjunto de nós (roteadores/hosts) e $E$ o conjunto de arestas (links de comunicação). A dinâmica do sistema evolui em passos de tempo discretos conforme as seguintes regras:

+ *Geração de Tráfego*:  A cada unidade de tempo, cada nó $s in V$ tem uma probabilidade $rho$ de gerar uma mensagem. O destino $t in (V without {s})$ de cada pacote é selecionado de forma aleatória uniformemente

+ *Capacidade de Transmissão*: Todos os nós participam ativamente do roteamento. Cada aresta possui uma capacidade finita $C$, definida como o número máximo de pacotes que podem ser transmitidos através da aresta por unidade de tempo. Caso o número de pacotes a serem enviados por uma aresta exceda sua capacidade, os pacotes remanescentes são armazenados em uma fila tipo *FIFO* (_First-In-First-Out_) contida na aresta, o sistema opera sob um mecanismo de armazenamento e repasse (_store-and-forward_).


+ *Estratégias de Roteamento*: O caminho $P$ percorrido por um pacote originado em $s$ e destino em $t$, é determinado por uma estratégia de roteamento, as estratégias analisadas serão as listas abaixo:
  - *Caminho Mínimo* _(Shortest Path_): O pacote escolhe uniformente um caminho no conjunto $cal(W)_(s t)$.

  - *Passeio Aleatório* (_Random Walk_): O caminho $P$ é construído por um processo estocástico em que $P_0=s$. A sequência é construída de forma iterativa, onde cada nó subsequente $P_(i+1)$ é selecionado uniforme entre os vizinhos contidos em $N_G (P_i)$, a condição de parada é quando o pacote chega ao seu destino $t$, ou seja, $P_(i)=t$.

  - *Visibilidade Limitada ($r$)*: A estratégia de roteamento alterna conforme a distância $d_(s t)$. Se $d(s, t) <= r$, utiliza-se o Caminho Mínimo, caso contrário, o pacote executa um Passeio Aleatório até que o destino entre no raio de visibilidade $r$.
Um resultado fundamental desse modelo é a existência de uma *taxa de geração crítica* $rho_c$, que define uma transição de fase no comportamento dinâmico do sistema:

+ *Fase de Fluxo Livre* ($rho < rho_c$): Após um período transiente de estabilização, a rede atinge um _estado estacionário_. Nesse regime, a quantidade total de pacotes na rede oscila em torno de um valor médio constante



+ *Fase de Congestionamento* ($rho > rho_c$): O sistema entra em um regime de saturação onde a taxa de geração de pacotes supera a capacidade de roteamento da rede. Isso resulta em um acúmulo linear de mensagens nas filas ao longo do tempo, caracterizando um estado não estacionário onde o tempo de espera e o atraso dos pacotes divergem para o infinito.

== Métrica de desempenho e atraso
Para caracterizar a eficiência do roteamento e identificar a transição de fase, define-se o *Atraso Médio* ($delta$). Esta grandeza representa o valor esperado do excesso de tempo de trânsito em relação ao cenário ideal de fluxo livre, sendo definida pela razão entre o tempo de permanência no grafo e a distância geodésica entre a origem e o destino:

$ delta := chevron.l (T_( s t)) / (d_(s t)) - 1 chevron.r $

Nesta formulação:

- $T_(s t)$: representa o tempo total decorrido desde a criação da mensagem até a sua entrega final.
- $d_(s t)$: é a distância de caminho mínimo, que define o tempo de trânsito em regime de fluxo livre (assumindo que cada aresta é percorrida em uma unidade de tempo).
- O termo $-1$: normaliza a métrica para que $delta approx 0$ em condições de baixa carga, onde o tempo de trânsito é próximo do limite inferior teórico.

Desta forma, $delta$ atua como um *parâmetro de ordem*: valores próximos de zero indicam um regime de *fluxo livre*, enquanto uma divergência em $delta$ sinaliza a fase de *congestionamento* da rede, onde o tempo de espera nas filas domina a dinâmica do sistema.


== Seleção uniforme em $cal(W)_(s t)$ <sec:seleção_uniforme_w>

Um desafio computacional intrínseco ao roteamento de caminhos mínimos sem viés reside na magnitude de $sigma_(s t)$, que frequentemente assume valores proibitivos para o armazenamento explícito de todos os caminhos possíveis #footnote[Como $sigma_(s t)$ pode atingir ordens de magnitude elevadas, há risco de *overflow* em tipos numéricos de tamanho fixo. O simulador desenvolvido utiliza a biblioteca *num-bigint*, que provê inteiros de precisão arbitrária.]. Para mitigar essa limitação, utiliza-se a estratégia de amostragem uniforme fundamentada em #cite(<dreyerOptimalUniformShortest2025>, form: "prose"). Tal método viabiliza a escolha aleatória de caminhos utilizando apenas a matriz de distâncias $d_(s t)$ e a matriz de contagem de caminhos mínimos $sigma_(s t)$.

Para a implementação deste método, define-se o conjunto de *vértices sucessores* de um nó $v$ em relação a um destino $t$. Um vértice $u$ é considerado predecessor de $v$ se for adjacente a $v$ e estar mais próximo de $t$. Formalmente, o conjunto de sucessores é dado por $N^-(v) = {u in N(v) : d_(u t) = d_(v t) - 1}$.

#let original_graph = ```
graph {
    graph [
    pad=0.05,
    margin=0,
    nodesep=0.2, // Diminui espaço horizontal entre nós
    ranksep=0.2, // Diminui espaço vertical entre níveis
    overlap=false,
    splines=true
  ];
    0 [color="red" ]
    1 [ ]
    2 [ ]
    3 [ ]
    4 [ ]
    5 [ ]
    6 [ ]
    7 [ ]
    8 [ ]
    0 -- 1 [ ]
    0 -- 2 [ ]
    0 -- 3 [ ]
    1 -- 2 [ ]
    1 -- 4 [ ]
    2 -- 4 [ ]
    3 -- 4 [ ]
    3 -- 5 [ ]
    4 -- 6 [ ]
    4 -- 7 [ ]
    5 -- 6 [ ]
    5 -- 7 [ ]
    6 -- 8 [ ]
    7 -- 8 [ ]
}
```.text



#let graph_dag = ```
digraph {
    graph [
      pad=0.05,
      margin=0,
      nodesep=0.2, // Diminui espaço horizontal entre nós
      ranksep=0.2, // Diminui espaço vertical entre níveis
      overlap=false,
      splines=true
    ];
    rankdir="BT"
    0 [ label = 0,color="red"]
    1 [ label = 1]
    2 [ label = 1]
    3 [ label = 1]
    4 [ label = 2]
    5 [ label = 2]
    6 [ label = 3]
    7 [ label = 3]
    8 [ label = 4]
    1 -> 0 [ label = "1.00", color = "#0095e7"]
    2 -> 0 [ label = "1.00", color = "#0095e7"]
    3 -> 0 [ label = "1.00", color = "#0095e7"]
    4 -> 1 [ label = "0.33", color = "#c1d0e7"]
    4 -> 2 [ label = "0.33", color = "#c1d0e7"]
    4 -> 3 [ label = "0.33", color = "#c1d0e7"]
    5 -> 3 [ label = "1.00", color = "#0095e7"]
    6 -> 4 [ label = "0.75", color = "#7caee7"]
    6 -> 5 [ label = "0.25", color = "#cbd6e7"]
    7 -> 4 [ label = "0.75", color = "#7caee7"]
    7 -> 5 [ label = "0.25", color = "#cbd6e7"]
    8 -> 6 [ label = "0.50", color = "#aac4e7"]
    8 -> 7 [ label = "0.50", color = "#aac4e7"]
}
```.text



#let n = 12
#let mapping = (:)

#for i in range(n) {
  let letter = std.str.from-unicode(65 + i)
  if letter == "A" {
    mapping.insert(str(i), "t")
  } else {
    mapping.insert(str(i), lower(letter))
  }
}


#align(center)[
  #scale(80%)[
    #figure(
      grid(
        columns: (1fr, 1fr),
        stroke: gray,
        fill: gray.lighten(90%),
        inset: 10pt,
        align: horizon,
        [
          #text(size: 10pt, weight: "bold", gray.darken(50%))[Grafo Original]
          #diagraph.render(original_graph, labels: mapping, height: 35%)
        ],
        [
          #text(size: 10pt, weight: "bold", gray.darken(50%))[DAG de Caminhos Mínimos]
          #diagraph.render(graph_dag, labels: mapping, height: 35%)
        ],
      ),
      caption: [Comparação entre o grafo original e o DAG com raiz em $t$. Qualquer pacote com destino em $t$ terá probabilidades de transição dada pelo peso das arestas que conecta a seus vizinhos da DAG],
    )]
]




O método consiste em modelar o roteamento como uma cadeia de Markov com estado inicial em um nó $s$ e estado terminal em $t$. Para um vértice $u$, a probabilidade de transição para um sucessor $v in N^-(u)$ é definida pelo peso:

$ P(u -> v) = sigma_(v t) / sigma_(u t) $

Demonstra-se que este conjunto de probabilidades resulta em uma seleção estritamente uniforme. Seja $p = (v_0, v_1, dots,v_(k-1), v_k)$ um caminho mínimo entre $s$ e $t$, com $v_0 = s$ e $v_0 = t$. A probabilidade de selecionar este caminho específico $P(p)$ é o produtório das transições de cada salto:

$ P(p) = product_(i=0)^(k) P(v_i -> v_(i+1)) = product_(i=0)^(k) sigma_(v_(i+1) t) / sigma_( v_i t) $

Ao expandir o produtório, observa-se um cancelamento telescópico e o resultado esperado:

$
  P(p) = sigma_(v_(1)t) / sigma_(v_0 t) dot sigma_(v_(2) t) / sigma_(v_(1) t) dot dots dot sigma_(v_(k) t) / sigma_(v_(k-1) t) = sigma_( v_k t) / sigma_(v_0 t) = (sigma_(t t))/(sigma_(s t))=1/ (sigma_(s t))
$

== Centralidade de intermediação e número de mensagens



== Modelos de Grafo

Diferentes algoritmos de geração de grafos servem como modelos de referência para a análise de redes complexas. Para fins de comparação e análise de desempenho em cenários de tráfego, foram selecionados os seguintes modelos:

- *Erdős-Rényi $G(N, E)$:* Define-se como um grafo selecionado uniformemente a partir do conjunto de todos os grafos possíveis com $N$ vértices e $$ arestas. Estudado originalmente por #cite(<erdosEvolutionRandomGraphs2011>, form: "prose"), este modelo serve como controle estatístico para testar a hipótese nula de que propriedades na rede decorrem de uma topologia específica ou se são meramente fruto de conexões aleatórias.

- *Barabási-Albert $B A(n, m)$:* Caracteriza-se por um processo de crescimento dinâmico que incorpora o mecanismo de ligação preferencial. O algoritmo inicia-se com um grafo de $m_0$ nós e, a cada iteração, um novo nó é adicionado com $m$ arestas ($m <= m_0$). A probabilidade $Pi$ de que o novo nó se conecte a um nó $i$ existente é proporcional ao seu grau $k_i$, conforme a relação:
  $ Pi_i = k_i / (sum_j k_j) $
  Este modelo, proposto por #cite(<barabasiEmergenceScalingRandom1999>, form: "prose") reproduz a distribuição de grau em lei de potência observada em redes de infraestrutura e tráfego reais.

- *Watts–Strogatz $W S(n, K, beta)$*: Modelo proposto por #cite(<wattsCollectiveDynamicsSmallworld1998>, form: "prose") para modelar o fenômeno de "mundo pequeno" em que redes exibem simultaneamente alto coeficiente de agrupamento e distâncias médias pequenas. O modelo inicia com um grafo regular onde cada nó está conectado aos seus $K$ vizinhos mais próximos, cada aresta é então rearranjada com probabilidade $beta$ para um nó escolhido aleatoriamente.
- *Grafo Geométrico Aleatório $G G A(n, r)$*: Neste modelo, os $n$ nós são distribuídos aleatoriamente em um espaço euclidiano,  uma aresta é estabelecida entre dois nós se, e somente se, a distância euclidiana entre eles for inferior a um raio de corte $r$.
== Algoritmo de garantia de conectividade <section:procedimento_conectividade>

Em modelos de análise de tráfego, a conetividade do grafo é uma propriedade necessária, pois garante que uma mensagem originada em qualquer nó $s$ seja capaz de alcançar qualquer destino $t$. Contudo, diversos modelos de redes, como o grafo aleatório de Erdős-Rényi, não garantem a conectividade global em todos os seus regimes de parâmetros.

Para transformar o grafo em conexo descaracterizando ao mínimo sua topologia original, aplica-se um procedimento heurístico de conexão de componentes via troca de arestas (_edge swap_). O algoritmo identifica as componentes conexas de $G$, portanto, $union_i C_i = V$, enquanto o grafo não for conexo, o algoritmo realiza a fusão entre duas componentes escolhidas aleatoriamente $C_a$ e $C_b$

O mecanismo de fusão fundamenta-se na seleção aleatória de arestas que apresentem redundância estrutural, ou seja, *arestas que não sejam pontes* (_bridges_). Uma aresta $(u, v)$ é uma ponte se sua remoção aumenta o número de componentes conectadas da rede, essas arestas podem ser encontradas usando o algoritmo de   #cite(<tarjanNoteFindingBridges1974>, form: "prose"). Ao selecionar uma aresta $(u, v) in E(C_a)$ e uma aresta $(x, y) in E(C_b)$ que pertençam a ciclos (não-pontes), garante-se que a remoção de ambas não fragmente as componentes originais antes da fusão.

Essas arestas são removidas e substituídas pelas aresta $(u, x)$ e $(v, y)$. Esta operação de re-cabeamento (_rewiring_) é matematicamente interessante pois preserva a sequência de graus, ou seja, o grau de cada nó permanece inalterado e conecta a componente $C_a$ com $C_b$.

Nos casos excepcionais onde uma das componentes é uma árvore ou um vértice isolado, situações em que não existem arestas que não sejam pontes, a conectividade é estabelecida pela inserção direta de uma nova aresta.

== Adaptação da capacidade dos elos <sec:adaptação_capacidade_elos>
Assume-se que o sistema opera em um *regime não crítico*, isto é, a taxa de geração de mensagens É suficientemente baixa para evitar o congestionamento, permitindo que a rede atinja um equilíbrio estatístico. No estado de equilíbrio, associa-se a cada aresta $e in E$ uma função densidade de probabilidade, denotada por $f_e$, que representa a distribuição do número de mensagens na fila em um instante qualquer.

Define-se a *Taxa de Fluxo Livre*, ou do inglês _Free Flow Rate_ (FFR) de uma aresta como a proporção de tempo em que o número de mensagens enfileiradas não excede a capacidade da aresta, ou seja, a fração do tempo em que as mensagens não sofrem atraso na sua entrega. Formalmente, para uma aresta $e$, a FFR é dada por:

$ "FFR"_e = P(X_e <= C_e) = F_e (C_e) $

onde $X_e$ é a variável aleatória do tamanho da fila, $C_e$ é a capacidade da aresta e $F_e$ é a função de distribuição acumulada que é calculada a partir da $f_e$.

Dado uma taxa mínima desejado para o fluxo livre, denotado por $eta$, uma questão de otimização é determinar uma configuração de capacidades $\{C_e : e in E\}$ tal que:

- Toda aresta satisfaça $F_e (C_e) >= eta$.
- A capacidade total do sistema, dada por $sum_{e in E} C_e$, seja minimizada.

Um algoritmo local heurístico que até o conhecimento do autor é inovador,é descrito logo em seguida.

Dado um intervalo de tempo $Delta T$ suficientemente longo para o sistema atingir o equilíbrio. Para cada aresta calcula-se nesse intervalo de tempo o histograma de número de mensagens recebidos, a partir desse histograma é atualizada a capacidade tal forma a ser a mínima capacidade necessária para atingir a FFR desejada durante o intervalo $Delta T$:

$ C_e = min {C in ZZ^+ : F_e (C) >= eta}, quad forall e in E. $ <eq:metodo>

Este procedimento atua como uma *heurística*, visto que a alteração da capacidade de uma única aresta pode influenciar a distribuição de tráfego em toda a rede. No entanto, ao aplicar iterativamente a @eq:metodo e permitir que o sistema se estabilize novamente em intervalos sucessivos $Delta T$, observa-se empiricamente a convergência para uma configuração estável que satisfaz a restrição de FFR enquanto tem uma capacidade total não muito grande.

Uma das vantagens desse método é por ele ser local, cada aresta só precisa de informação do seu próprio trafego observado, o que é uma características que torna a heurística escalável para redes de virtualmente qualquer tamanho

= RESULTADOS

Todos os grafos comparados foram gerados com parâmetros de forma a não diferirem em mais do que 1% no número de nós e de arestas, a conectividade foi garantido pelo procedimento descrito na @section:procedimento_conectividade, isso estabelece uma comparação justa em um cenário que se queira uma rede eficiente dado $N$ nós e $M$ conexões entre eles

== Sem adaptação <section:sem_adaptacao>


A @fig:rho_vs_atraso compara a eficiência dos 4 modelos de grafos escolhidos para a análise, a aferição exata do valor de $p_c$ pra cada grafo é difícil de ser feita pois os atrasos progressivamente vão aumentando sem demonstrar uma clara transição de fase, no entanto, visualmente é possível afirmar que:

#{
  set text(size: 11.5pt)
  $ p_c ("Erdős–Rényi")>p_c ("Watts–Strogatz")>p_c ("Barabási–Albert")>p_c ("Rede Geométrica") $
}


#let p_critico_df = csv("assets/tables/graph_stats.csv")


#let topology_to_color = (
  "Barabási–Albert": red,
  "Erdős–Rényi": blue,
  "Rede Geométrica": olive,
  "Watts–Strogatz": purple,
)

#let round_num(x, digits) = {
  [#calc.round(float(x), digits: digits)]
}

#let table_p_critico_df = table(
  columns: (1.5fr, 1fr, 1fr, 1fr, 1fr, 1fr),
  align: (left, center, center, center, center, center, center),
  table.hline(stroke: 1pt),
  table.header([*Grafo*], [*$N$*], [*$E$*], [*$d$*], [*$chevron.l L chevron.r$*], [*$C$*]),
  table.hline(stroke: 0.5pt),
  ..for (graph_name, _, n, e, d, l, c) in p_critico_df.slice(1) {
    (
      text(fill: topology_to_color.at(graph_name), stroke: 0.005em)[#graph_name],
      n,
      e,
      d,
      round_num(l, 2),
      round_num(c, 3),
    )
  },
  table.hline(stroke: 1pt),
)

#subpar.grid(
  figure(
    image("assets/plots/p_critico_delay.svg"),
    caption: [Atraso médio ($delta$)],
  ),
  <fig-atraso>,
  figure(
    image("assets/plots/p_critico_travel.svg"),
    caption: [Tempo médio de viagem],
  ),
  <fig-viagem>,
  columns: (1fr, 1fr),
  gutter: 10pt,
  grid.cell(colspan: 2, align(center, box(width: 80%, table_p_critico_df))),
  caption: [
    Análise comparativa da dinâmica de tráfego em diferentes topologias de rede.
    A tabela apresenta as propriedades estruturais: número de nós $N$, arestas $E$, diâmetro ($d$), distância esperada $chevron.l L chevron.r$ e coeficiente de agrupamento $C$.
  ],
  label: <fig:rho_vs_atraso>,
)

A distância média da rede é um fator  importante na sua eficiência, no regime de baixa geração de mensagens $p_c approx 0$, mesmo que o atraso seja próximo de nulo para todos os grafos
, o tempo médio de viagem dos pacotes é numericamente igual a $chevron.l L chevron.r$

Para um roteamento de mínimos caminhos, uma forma simples de prever quantas mensagens $M_e$ passam por uma aresta $e$ , é através da sua intermediação, como ilustra a @fig:intermediação_vs_mensagens existe uma relação linear entra ela e o número de mensagens, isso acontece pois a centralidade de intermediação mede a quantidade de mínimos caminhos que passam pela aresta, como o roteamento é por mínimos caminhos, essa grandeza mede diretamente o quanto é esperado de tráfego.

Como a geração de mensagens é um conjunto de ensaios de Bernoulli para cada vértice, o número total de mensagens geradas segue uma distribuição binominal $B(N,rho)$, podemos estimar $M_e$ como sendo:


$
  M_e ≃ sum_(s,t in V) underbrace(( B(N,rho))/(N(N-1)), #stack(dir: ttb, [Fração das mensagens geradas], [ com origem em $s$ e destino $t$])) times underbrace(sigma(s, t | e)/(sigma(s, t)), #stack(dir: ttb, [Fração dos caminhos mínimos ], [que passam por $e$]))=B(N,rho) times b_e
$


#let betweeness_vs_messages = csv(
  "assets/tables/betweeness_vs_messages.csv",
)


#let table_betweeness_vs_messages = table(
  columns: (1fr, 1fr, 1.5fr),
  align: (left, center, center, center),
  table.hline(stroke: 1pt),
  table.header([*Grafo*], [*$R^2$*], [*$alpha plus.minus Delta alpha$*]),
  table.hline(stroke: 0.5pt),
  ..for (graph_name, R_squared, alpha, delta_alpha, _, _) in betweeness_vs_messages.slice(1) {
    (
      text(fill: topology_to_color.at(graph_name), stroke: 0.005em)[#graph_name],
      round_num(R_squared, 2),
      num(alpha + "+-" + delta_alpha, exponent: "sci"),
    )
  },
  table.hline(stroke: 1pt),
)


#figure(
  stack(
    dir: ttb,
    spacing: 1.5em,
    image("assets/plots/p_critico_betweeness.svg", width: 80%),
    box(width: 65%)[#table_betweeness_vs_messages],
  ),
  caption: [Análise da correlação entre centralidade de intermediação de aresta e mensagens recebidas, $rho$ fixo em 0.1],
) <fig:intermediação_vs_mensagens>




Através dessa aproximação e utilizando a @eq:sum_edge_betweeness, chegamos em uma expressão da quantidade de mensagens que transitam na rede
$ sum_(e in E) M_e = B(N,rho) times chevron.l L chevron.r $ <eq:media_mensagens>


Um modelo de grafo que podemos variar a distância média fixando $N$ e $M$ é o modelo de Watts-Strogatz, com $beta approx 0$ (grafo regular) a distância é alta e é proporcional a $N$, já em $beta approx 1$ o modelo se aproxima de um grafo aleatório tendo $chevron.l L chevron.r$ baixo, para valores intermediários $0<beta<1$ é possível atingir redes de "mundo pequeno" em que $chevron.l L chevron.r$ é pequeno mas que $C$ é alto como ilusta a @fig:watts_strogatz_classico


#figure(
  image(
    "assets/plots/watts_classical_plot.svg",
    width: 50%,
  ),
  caption: [Modelo de Watts-Strogatz $W S(3000, 6, beta)$ em gráfico análogo ao artigo original @wattsCollectiveDynamicsSmallworld1998, demonstrando a possibilidade de gerar grafos aleatórios com diferentes valores de $chevron.l L chevron.r$],
) <fig:watts_strogatz_classico>

Realizando simulações em grafos Watts-Strogatz com diferentes valores de $beta$, conseguentemente diferentes valores de $chevron.l L chevron.r$, se observa na @fig:watts_messages_vs_time uma concordância com o número de mensagens esperado com a média e o desvio padrão teóricos, o número de mensagens oscila entorno de uma média com uma amplitude de oscilação dentro do esperado pelo desvio padrão



#figure(
  image(
    "assets/plots/watts_messages_vs_time.svg",
    width: 100%,
  ),
  caption: [Grafos Watts-Strogatz com diferentes valores de
    $chevron.l L chevron.r$, $mu$ é a média esperada de mensagens e  $sigma$ o desvio padrão esperado, ambos derivados da @eq:media_mensagens],
) <fig:watts_messages_vs_time>


== Com adaptação
Os resultados obtidos na seção anterior (@section:sem_adaptacao) suponha que todos as aresta tinham capacidade unitaria constante no tempo, agora o método descrito na seção (@sec:adaptação_capacidade_elos) de adaptação das capacidades dada o tráfego será o usado, nos mesmos grafos e nas mesmas condições


#figure(
  image("assets/plots/p_critico_travel_adapted_capacity.svg"), 
  caption: [Comparação da eficiência das mesmas \
    redes com/sem adaptação da capacidades das arestas]
)

#figure(
  image("assets/plots/p_critico_capacity_adapted_capacity.svg")
)


= CONCLUSÕES E CONSIDERAÇÕES FINAIS




#bibliography(
  "bibliography/zotero.bib",
  title: [REFERÊNCIAS],
  style: "associacao-brasileira-de-normas-tecnicas",
  full: false,
)
