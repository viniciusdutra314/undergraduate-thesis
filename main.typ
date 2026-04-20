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

#let resumo_conteudo=par[
  A análise de redes complexas tem demonstrado uma notável versatilidade interdisciplinar, fundamentada na matemática da teoria de grafos. Essa abordagem permite modelar sistemas heterogêneos sob uma linguagem matemática unificada, estendendo-se desde aplicações macroscópicas como a modelagem de tráfego e o planejamento urbano baseados em grafos geométricos até em computação quântica na otimização do mapeamento de algoritmos em circuitos físicos. O presente trabalho consiste na realização de simulações de tráfego em grafos, visando investigar estratégias de otimização na entrega de pacotes para diversas topologias e protocolos de roteamento. 
  Para viabilizar a análise e roteamento em grafos de porte médio  em um computador doméstico, o simulador foi desenvolvido na linguagem Rust. Essa escolha fundamenta-se na necessidade de aliar o desempenho de uma linguagem compilada a garantias rigorosas de segurança de memória e concorrência sem condições de corrida . A implementação atual permite a execução paralela de simulações em redes compostas por milhares de nós, utilizando a biblioteca de alto desempenho _rustworkx_ para a manipulação eficiente das estruturas de dados do grafo e algoritmos.]


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



Palavras-chave: Redes complexas. Teoria de Grafos.



= INTRODUÇÃO
== Teoria de grafos
Definimos um grafo $G$ como um par ordenado $G = (V, E)$, onde $V$ é um conjunto finito e não vazio de elementos denominados *vértices*, e $E$ é um conjunto de pares não ordenados de elementos de $V$, denominados *arestas*. @trudeauIntroductionGraphTheory1993.


Um *caminho* entre dois vértices $s, t in V$ é definido como uma sequência de vértices $P = (v_0, v_1, ..., v_k)$ tal que $v_0 = s$, $v_k = t$, e para todo $i$ tal que $0 <= i < k$, a aresta $(v_i, v_{i+1})$ pertence ao conjunto $E$. O *comprimento* do caminho é dado por $k$, que corresponde ao número de arestas na sequência. É importante notar que tal caminho pode não existir; nesse caso, diz-se que $t$ é inatingível a partir de $s$. Um grafo é dito *conexo* se, para todo par de vértices, existe pelo menos um caminho que os conecta, caso contrário, o grafo é classificado como *desconexo*.

Um *caminho mínimo* entre dois vértices $s$ e $t$ é um caminho cujo comprimento $k$ é o menor possível dentre todos os caminhos existentes entre esses vértices. Ressalta-se que o caminho mínimo não é necessariamente único.  A *distância* entre $s$ e $t$, denotada por $d(s, t)$, é definida como o comprimento desse caminho mínimo. Convenciona-se que, caso não exista caminho entre $s$ e $t$, $d(s, t) = infinity$. 
#footnote[Em implementações computacionais, sistemas que utilizam a representação de ponto flutuante segundo o padrão IEEE 754 @noauthor_ieee_2019 possuem uma representação de infinito com propriedades robustas]

A partir da definição de caminhos mínimos, derivam-se duas métricas topológicas fundamentais para a caracterização do modelo de tráfego. A primeira é a *distância média* $chevron.l L chevron.r$, que representa o valor esperado do comprimento do caminho mínimo entre dois vértices quaisquer da rede.

$ chevron.l L chevron.r := 1 / (|V|(|V|-1)) sum_(i != j) d_(i j) $ <equacao:foda>

A segunda métrica é a *Centralidade de Intermediação de Aresta* (_Edge Betweenness Centrality_) @brandesVariantsShortestpathBetweenness2008a, que quantifica o quanto uma aresta é visitada por caminhos mínimos. A centralidade de intermediação da aresta $e$, denotada por $c_B (e)$, é definida como a soma das frações de todos os caminhos mínimos da rede que passam por essa aresta normalizada pelo número de arestas possíveis:

$ c_B(e) =  1 / (N(N-1)) sum_(s, t in V) (sigma(s, t | e)) / (sigma(s, t)) $

Seja $cal(W)_(s t)$ o conjunto de todos os caminhos mínimos de um vértice origem $s$ até um destino $t$. Definimos o valor $sigma(s, t) := |cal(W)_(s t)|$ como a cardinalidade deste conjunto, isto é, o número total de caminhos mínimos possíveis entre $s$ e $t$. Para uma dada aresta $e in E$, denotamos por $sigma(s, t | e)$ a quantidade desses caminhos mínimos que passam  por $e$.



Foi escolhido a definição de $c_B (e)$ com o fator de normalização para que uma relação ficasse mais simples, conforme demonstrado por @brandesMaintainingDualityCloseness2016, a soma das centralidades de intermediação de todas as arestas de um grafo é igual a distância média.

$ chevron.l L chevron.r = sum_(e in E) c_B (e) $

Esse resultado é importante para analisar como a topologia da rede influência o tráfego de pacotes


== Formalização do modelo de tráfego de pacotes <sec:formalização_modelo_trafego>

Baseado na meta-análise de @chen_traffic_2012, estamos usando um modelo de trafego simples porém usual em artigos de redes complexas, o sistema é descrito por um grafo e um conjunto de regras dinâmicas de geração e roteamento de informação.


Seja $G = (V, E)$ um grafo conexo, não direcionado e não ponderado, onde $V$ representa o conjunto de nós (roteadores/hosts) e $E$ o conjunto de arestas (links de comunicação). A dinâmica do sistema evolui em passos de tempo discretos conforme as seguintes premissas:

+ *Geração de Tráfego*:  A cada unidade de tempo, cada nó $s in V$ tem uma probabilidade $rho$ de gerar uma mensagem. O destino $t in V$ de cada pacote é selecionado uniformemente ao acaso no conjunto de nós, tal que $t != s$.

+ *Capacidade de Transmissão*: Todos os nós participam ativamente do roteamento. Cada aresta possui uma capacidade finita $C$, definida como o número máximo de pacotes que podem ser transmitidos através da aresta por passo de tempo. Caso o número de pacotes a serem enviados por uma aresta exceda sua capacidade, os pacotes remanescentes são armazenados em uma fila tipo *FIFO* (_First-In-First-Out_) contida na aresta, o sistema opera sob um mecanismo de armazenamento e repasse (_store-and-forward_).


+ *Estratégias de Roteamento*: O caminho percorrido por um pacote entre $s$ e $t$ é determinado por uma estratégia de roteamento, tais como:
  - *Caminho Mínimo* _(Shortest Path_): O pacote segue pela menor distância topológica entre a origem e o destino.
  - *Caminhada Aleatório* (_Random Walk_): O próximo nó é escolhido aleatoriamente entre os vizinhos.
  - *Visibilidade Limitada*: O roteamento é 
    do tipo Caminho Mínimo ou Caminhada Aleatória com base em uma distância limite do destino.

Um resultado fundamental desse modelo é a existência de uma *taxa de geração crítica* $rho_c$, que define uma transição de fase no comportamento dinâmico do sistema:

+ *Fase de Fluxo Livre* ($rho < rho_c$): Após um período transiente de estabilização, a rede atinge um _estado estacionário_. Nesse regime, a quantidade total de pacotes na rede oscila em torno de um valor médio constante

+ *Fase de Congestionamento* ($rho > rho_c$): O sistema entra em um regime de saturação onde a taxa de geração de pacotes supera a capacidade de roteamento da rede. Isso resulta em um acúmulo linear de mensagens nas filas ao longo do tempo, caracterizando um estado não estacionário onde o tempo de espera e o atraso dos pacotes divergem para o infinito.

=== Métrica de desempenho e atraso

Para caracterizar a eficiência do roteamento e identificar a transição de fase, define-se o *Atraso Médio* ($delta$). Esta grandeza representa o valor esperado do excesso de tempo de trânsito em relação ao cenário ideal de fluxo livre, sendo definida pela razão entre o tempo de permanência no grafo e a distância geodésica entre a origem e destino:

$ delta := chevron.l (T_"total") / (d_"min") - 1 chevron.r $

Nesta formulação:

- $T_"total"$: representa o tempo total decorrido desde a criação da mensagem até sua entrega.
- $d_"min"$: é a distância de caminho mínimo que define o tempo de trânsito em regime de fluxo livre.
- O termo $-1$: desloca a métrica para que $delta ≃ 0$ em condições de baixa carga, onde o tempo de trânsito é próximo do ideal

Desta forma, $delta$ atua como um _parâmetro de ordem_: valores próximos de zero indicam um regime de *fluxo livre*, enquanto uma divergência em $delta$ sinaliza o início do *congestionamento global* da rede.

#pagebreak()
= Materiais e Métodos 
= Resultados 
= Conclusões e considerações finais  

#pagebreak()
#bibliography("zotero.bib",
title:[Referências],
style: "associacao-brasileira-de-normas-tecnicas")

