#import "tcc_template.typ": tcc_generate_cover
#import "@preview/algorithmic:1.0.7": *
#import "@preview/wordometer:0.1.5":*


#{
  if sys.version!=version(0,14,2){
    panic("O documento foi feito em Typst 0.14.2, talvez não funcione em outra versão")
  }
}
#show: tcc_generate_cover.with()


#heading("RESUMO",numbering: none
) <text:introducao>

#context {
  let secoes_presentes =  query(heading.where(level: 1)).map(h => h.body.text)
  
  let secoes = (
    "RESUMO", 
    "INTRODUÇÃO", 
    "MATERIAIS E MÉTODOS", 
    "RESULTADOS", 
    "CONCLUSÕES E CONSIDERAÇÕES FINAIS",
    "REFERÊNCIAS"
  )
  assert(secoes.sorted()==secoes_presentes.sorted(),message: "Existe uma seção que não deveria existir ou que está faltando")
}


#let resumo_conteudo=par[
  #lorem(200).]


//invariantes sobre a seção de resumo
#word-count(wc => {
  assert(wc.words < 500,message: "Resumo com mais de 500 palavras")
  assert(resumo_conteudo.func()==par,message: "Resumo deve ser somente um paragráfo")
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
- *Alocação de Capacidade:* Propor e testar heurísticas para a distribuição não uniforme das capacidades de transmissão ($C$) entre as arestas, visando a minimização da  capacidade total da rede, avaliando como essa adaptação afeta o Atraso Médio ($delta$) e a geração crítica de mensagens $(p_c)$.
- *Avaliação de Estratégias de Roteamento:* Comparar a eficiência das adaptações de capacidade propostas quando submetidas a diferentes algoritmos de roteamento, como Caminho Mínimo (_Shortest Path_) e estratégias de Visibilidade Limitada.
- *Análise Topológica:* Investigar a relação entre métricas topológicas, como a Centralidade de Intermediação de Aresta ($c_B(e)$)  e o tráfego resultante em diferentes redes como Erdos-Rényi, Barabási-Albert, redes em grade, etc.


== Teoria de grafos
Definimos um grafo $G$ como um par ordenado $G = (V, E)$, onde $V$ é um conjunto finito e não vazio de elementos denominados *vértices*, e $E$ é um conjunto de pares não ordenados de elementos de $V$, denominados *arestas*. @trudeauIntroductionGraphTheory1993. 

Dois vértices $u, v in V$ são ditos *adjacentes* se existir uma aresta ${u, v} in E$. O vértice $v$ é denominado *vizinho* de $u$, e vice-versa. O conjunto de todos os vértices adjacentes a um vértice $v$ define a sua *vizinhança*, denotada por $N_G (v)$. A cardinalidade deste conjunto, que representa o número de arestas incidentes ao vértice, define o seu *grau*, denotado por $deg(v)$.

Um *caminho* entre dois vértices $s, t in V$ é definido como uma sequência de vértices $P = (v_0, v_1, ..., v_k)$ tal que $v_0 = s$, $v_k = t$, e para todo $i$ tal que $0 <= i < k$  ${v_i, v_{i+1}} in E$. O *comprimento* do caminho é dado por $k$, que corresponde ao número de arestas na sequência. É importante notar que tal caminho pode não existir; nesse caso, diz-se que $t$ é inatingível a partir de $s$. Um grafo é dito *conexo* se, para todo par de vértices, existe pelo menos um caminho que os conecta, caso contrário, o grafo é classificado como *desconexo*.

Um *caminho mínimo* entre dois vértices $s$ e $t$ é um caminho cujo comprimento $k$ é o menor possível dentre todos os caminhos existentes entre esses vértices. Ressalta-se que o caminho mínimo não é necessariamente único.  A *distância* entre $s$ e $t$, denotada por $d_(s t)$, é definida como o comprimento desse caminho mínimo. Convenciona-se que, caso não exista caminho entre $s$ e $t$, $d(s, t) = infinity$. 
#footnote[Em implementações computacionais, sistemas que utilizam a representação de ponto flutuante segundo o padrão IEEE 754 @noauthor_ieee_2019 possuem uma representação de infinito com propriedades desejáveis para vértices inatingíveis.]

A partir da definição de caminhos mínimos, derivam-se duas métricas topológicas fundamentais para a caracterização do modelo de tráfego. A primeira é a *distância média* $chevron.l L chevron.r$, que representa o valor esperado do comprimento do caminho mínimo entre dois vértices quaisquer da rede.

$ chevron.l L chevron.r := 1 / (|V|(|V|-1)) sum_(i != j) d_(i j) $ <equacao:foda>

A segunda métrica é a *Centralidade de Intermediação de Aresta* (_Edge Betweenness Centrality_) @brandesVariantsShortestpathBetweenness2008a, que quantifica a frequência em que uma aresta é visitada por caminhos mínimos. A centralidade de intermediação da aresta $e$, denotada por $c_B (e)$, é definida como a soma das frações de todos os caminhos mínimos da rede que passam por essa aresta, normalizada pelo número de arestas possíveis:

$ c_B(e) =  1 / (|V|(|V|-1)) sum_(s, t in V) (sigma(s, t | e)) / (sigma(s, t)) $

Seja $cal(W)_(s t)$ o conjunto de todos os caminhos mínimos de um vértice origem $s$ até um destino $t$. Definimos o escalar $sigma(s, t) := |cal(W)_(s t)|$ como a cardinalidade deste conjunto, isto é, o número total de caminhos mínimos possíveis entre $s$ e $t$. Para uma dada aresta $e in E$, denotamos por $sigma(s, t | e)$ a quantidade desses caminhos mínimos que passam  por $e$.



A definição de $c_B (e)$ foi escolhida com o fator de normalização para que uma relação ficasse mais simples, conforme demonstrado por @brandesMaintainingDualityCloseness2016, a soma das centralidades de intermediação de todas as arestas de um grafo é igual a distância média. Esse resultado é importante para analisar como a topologia da rede influencia o tráfego de pacotes


$ chevron.l L chevron.r = sum_(e in E) c_B (e) $



== Formalização do modelo de tráfego de pacotes <sec:formalização_modelo_trafego>

Baseado na meta-análise de @chen_traffic_2012, utilize-se um modelo de trafego simples porém usual em artigos de trafego de pacotes, o sistema é descrito por um grafo e um conjunto de regras dinâmicas de geração e roteamento de informação.


Seja $G = (V, E)$ um grafo conexo, não direcionado, onde $V$ representa o conjunto de nós (roteadores/hosts) e $E$ o conjunto de arestas (links de comunicação). A dinâmica do sistema evolui em passos de tempo discretos conforme as seguintes regras:

+ *Geração de Tráfego*:  A cada unidade de tempo, cada nó $s in V$ tem uma probabilidade $rho$ de gerar uma mensagem. O destino $t in (V  without {s}) $ de cada pacote é selecionado de forma aleatória uniformemente 

+ *Capacidade de Transmissão*: Todos os nós participam ativamente do roteamento. Cada aresta possui uma capacidade finita $C$, definida como o número máximo de pacotes que podem ser transmitidos através da aresta por unidade de tempo. Caso o número de pacotes a serem enviados por uma aresta exceda sua capacidade, os pacotes remanescentes são armazenados em uma fila tipo *FIFO* (_First-In-First-Out_) contida na aresta, o sistema opera sob um mecanismo de armazenamento e repasse (_store-and-forward_).


+ *Estratégias de Roteamento*: O caminho $P$ percorrido por um pacote originado em $s$ e destino em $t$, é determinado por uma estratégia de roteamento, as estratégias analisadas serão as listas abaixo:
  - *Caminho Mínimo* _(Shortest Path_): O pacote escolhe uniformente um caminho no conjunto $cal(W)_(s t)$.
  
  - *Passeio Aleatório* (_Random Walk_): O caminho $P$ é construído por um processo estocástico em que $P_0=s$. A sequência é construída de forma iterativa, onde cada nó subsequente $P_(i+1)$ é selecionado uniforme entre os vizinhos contidos em $N_G (P_i)$, a condição de parada é quando o pacote chega ao seu destino $t$, ou seja, $P_(i)=t$.
  
  - *Visibilidade Limitada ($r$)*: A estratégia de roteamento alterna conforme a distância $d_(s t)$. Se $d(s, t) <= r$, utiliza-se o Caminho Mínimo, caso contrário, o pacote executa um Passeio Aleatório até que o destino entre no raio de visibilidade $r$.
Um resultado fundamental desse modelo é a existência de uma *taxa de geração crítica* $rho_c$, que define uma transição de fase no comportamento dinâmico do sistema:

+ *Fase de Fluxo Livre* ($rho < rho_c$): Após um período transiente de estabilização, a rede atinge um _estado estacionário_. Nesse regime, a quantidade total de pacotes na rede oscila em torno de um valor médio constante

+ *Fase de Congestionamento* ($rho > rho_c$): O sistema entra em um regime de saturação onde a taxa de geração de pacotes supera a capacidade de roteamento da rede. Isso resulta em um acúmulo linear de mensagens nas filas ao longo do tempo, caracterizando um estado não estacionário onde o tempo de espera e o atraso dos pacotes divergem para o infinito.



=== Métrica de desempenho e atraso

Para caracterizar a eficiência do roteamento e identificar a transição de fase, define-se o *Atraso Médio* ($delta$). Esta grandeza representa o valor esperado do excesso de tempo de trânsito em relação ao cenário ideal de fluxo livre, sendo definida pela razão entre o tempo de permanência no grafo e a distância geodésica entre a origem e o destino:

$ delta := chevron.l (T_( s t)) / (d_(s t)) - 1 chevron.r $

Nesta formulação:

- $T_(s t)$: representa o tempo total decorrido desde a criação da mensagem até a sua entrega final.
- $d_(s t)$: é a distância de caminho mínimo, que define o tempo de trânsito em regime de fluxo livre (assumindo que cada aresta é percorrida em uma unidade de tempo).
- O termo $-1$: normaliza a métrica para que $delta approx 0$ em condições de baixa carga, onde o tempo de trânsito é próximo do limite inferior teórico.

Desta forma, $delta$ atua como um *parâmetro de ordem*: valores próximos de zero indicam um regime de *fluxo livre*, enquanto uma divergência em $delta$ sinaliza a fase de *congestionamento* da rede, onde o tempo de espera nas filas domina a dinâmica do sistema.

= MATERIAIS E MÉTODOS 


Dada a elevada combinatória de dinâmicas em grafos de médio porte ($|V| approx 10^3$), o simulador foi desenvolvido na linguagem Rust visando assegurar a viabilidade computacional das simulações em hardware convencional. Esta escolha fundamenta-se na necessidade de conciliar o desempenho de uma linguagem compilada a garantias rigorosas de segurança de memória, concorrência sem condições de corrida e corretude dos resultados @jungRustBeltSecuringFoundations2017. A implementação atual permite a execução paralela de simulações em redes compostas por milhares de nós, utilizando a biblioteca de alto desempenho _rustworkx_ @treinish_rustworkx_2022 para a manipulação eficiente de algoritmos e estruturas de dados.

A verificação da corretude do simulador foi realizada por uma extensa

= RESULTADOS
= CONCLUSÕES E CONSIDERAÇÕES FINAIS

#bibliography("zotero.bib",
title:[REFERÊNCIAS],
style: "associacao-brasileira-de-normas-tecnicas",full:false)

