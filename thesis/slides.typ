#import "main.typ" as tcc
#import "tcc_template.typ" as tcc_template
#import "@preview/polylux:0.4.0"
#import "@preview/diatypst:0.9.1": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

#{
  if sys.version != version(0, 14, 2) {
    panic("O documento foi feito em Typst 0.14.2, talvez não funcione em outra versão")
  }
}

#set text(lang: "pt", region: "br", hyphenate: false)
#set par(
  justify: true,
  leading: 0.65em,
)
#show: slides.with(
  title: [#tcc_template.titulo],
  authors: ([#tcc_template.nome_aluno].text),
  count: "number",
  ratio: 16 / 9,
  layout: "medium",
  title-color: blue.darken(60%),
  toc: true,
)

#set figure(numbering: none)


= Introdução

== Exemplos de aplicação
#grid(
  rows: (1fr, 1fr),
  columns: (1fr, 1fr),
  figure(
    image("assets_slides/sao_carlos.svg"),
    caption: "Rede de ruas de São Carlos",
  ),
)

= Metodologia


== Modelos de grafos
#grid(
  rows: 1,
  columns: (1fr, 1fr, 1fr, 1fr),
  gutter: 0.5cm,

  [#align(center)[#rect(width: 100%, height: 100%, stroke: 0.5pt + gray, radius: 3pt)[
    Erdős-Rényi (1959)
    #image("assets_slides/erdos.svg")
    #text(size: 10pt)[
      - Grafo escolhido uniformemente no conjunto $cal(G)(n, m)$
      - *Hipótese nula*
    ]
  ]]],
  [#align(center)[#rect(width: 100%, height: 100%, stroke: 0.5pt + gray, radius: 3pt)[
    Geométrico (1961)
    #image("assets_slides/rgg.svg")
    #text(size: 10pt)[
      - Nós  uniformemente distribuídos, arestas entre nós próximos
      - *Exemplos:* Redes de sensores sem fio, redes de contágio por proximidade física.
    ]
  ]]],
  [#align(center)[#rect(width: 100%, height: 100%, stroke: 0.5pt + gray, radius: 3pt)[
    Watts-Strogatz (1998)
    #image("assets_slides/watts.svg")
    #text(size: 10pt)[
      - Um grafo regular com uma fração de arestas aleatórias
      - *Exemplos:* Redes de mundo pequeno, como redes sociais e redes de colaboração científica.
    ]
  ]]],
  [#align(center)[
    #rect(width: 100%, height: 100%, stroke: 0.5pt + gray, radius: 3pt)[
      Barabási-Albert (1999)
      #image("assets_slides/barabasi.svg")
      #text(size: 10pt)[
        - Grafo gerado por crescimento com ligação preferêncial
        - *Exemplos:* A rede de hiperlinks da internet, redes de citação científica
      ]
    ]
  ]],
)
== Modelo de tráfego

A cada instante de tempo, cada nó *$s$* tem uma probabilidade *$rho$* de gerar uma mensagem a um destino *$t$* escolhido aleatoriamente. Cada aresta *$e$* tem uma capacidade *$C_e$* de roteamento, se o número de mensagens  exceder essa capacidade, as mensagens são colocadas em uma fila FIFO (First In, First Out), resultando em atrasos.

#let message(source, destination, color: rgb("#dbeafe")) = {
  rect(
    inset: 8pt,
    radius: 4pt,
    fill: color,
    stroke: rgb("#1e40af"),
    [
      *Mensagem*
      #linebreak()
      origem: #source
      #linebreak()
      destino: #destination
    ]
  )
}

#align(center)[
  #diagram(
    spacing: 2.5cm, 
    node((0,0), circle([$a$], radius: 20pt), name: <node-a>),
    
    edge(<node-a>, <node-fila>, "-|>", stroke: 1pt),
    
    node((1,0), box(
      stroke: blue,
      inset: 6pt,
      radius: 4pt,
      [
        #align(center)[*Fila FIFO*]
        #v(0.5em)
        #stack(
          dir: ltr,
          spacing: 0.4em,
          message(1, 15),
          message(53, 195),
          message(63, 356),
        )
        #v(0.5em)
        #align(center)[
          Primeiro a entrar $arrow.r$ Primeiro a sair
        ]
      ]
    ), name: <node-fila>),
    
    edge(<node-fila>, <node-b>, "-|>", stroke: 1pt,label:[Até $C_e$ por vez]),
    node((2,0), circle([$b$], radius: 20pt), name: <node-b>),
  )
]


#v(1em)



== Tipos de roteamento

#let colors_roteamento = (
  "Mínimos caminhos": blue,
  "Visibilidade limitada": green,
  "Caminhada aleatória": orange,
)


#grid(
  rows: 1,
  columns: (1fr, 1fr),
  [
    - #text(fill: orange)[Caminhada aleatória]: Um vizinho aleatório é escolhido para encaminhar a mensagem, sem informação global sobre a topologia.

    - #text(fill: green)[Visibilidade limitada]: Realiza roteamento por mínimos caminhos somente até uma distância máxima $k$.

    - #text(fill: blue)[Caminhos mínimos]:
      Tem conhecimento global da topologia e encaminha a mensagem para um caminho mínimo.
    #table(
      columns: (1fr, 1fr),
      table.header([Roteamento], [Comprimento]),
      ..for (graph_name, distance) in csv("assets_slides/roteamentos_comprimentos.csv").slice(1) {
        ([#text(fill: colors_roteamento.at(graph_name))[#graph_name]], [#distance])
      },
    )
  ],

  figure(
    caption: "Comparação dos comprimentos dos roteamentos em um quadrado 20 x 20",
    image("assets_slides/modelos_roteamento.svg"),
  ),
)

== Metódo da adaptação de capacidades

O número de mensagens na aresta é registrado durante um período $T$ de amostragem, criando assim um histograma de frequências. Uma fração desejada de tempo que a aresta deve estar livre de congestionamento $eta$ é escolhida, a capacidade de cada aresta é atualizada
$C_e -> sqrt(C_e times min {C in ZZ^+ : F_e (C) >= eta})$.
#figure(
  image("assets/plots/histogram_example.svg", height: 76%),
)

== Implementação Computacional

#grid(
  columns: 2,
  gutter: 30pt,
  diagram(
    spacing: (2cm, 1.5cm),
    node(
      (0, 0),

      grid(
        columns: (0.5fr, 1fr),
        image("assets_slides/julia-dots.svg", height: 175%),
        [
          *Análise: Julia + Makie*

        ],
      ),

      fill: rgb("#b9c2ca"),
      stroke: none,
      inset: 15pt,
      radius: 3pt,
      width: 8cm,
      height: 1.75cm,
    ),

    edge((0., 1), (0, 0), "-|>", shift: 0.5cm, stroke: 1pt + rgb("4a4a4a")),

    node(
      (0, 1),

      grid(
        columns: (0.5fr, 1fr),
        image("assets_slides/hdf_logo.png", height: 100%), [*Persistência: HDF5*],
      ),
      fill: rgb("#b9c2ca"),
      stroke: none,
      inset: 15pt,
      radius: 2pt,
      width: 8cm,
      height: 1.75cm,
    ),

    edge((0, 2), (0, 1), "-|>", shift: 0.5cm, stroke: 1pt + rgb("4a4a4a")),
    node(
      (0, 2),
      grid(
        columns: (0.5fr, 1fr),
        image("assets_slides/ferris-flat-noshadow.svg", height: 150%),
        [
          *Simulador: Safe Rust*\
          (Opensource licença MIT)
        ],
      ),
      fill: rgb("b9c2ca"),
      stroke: none,
      inset: 15pt,
      radius: 2pt,
      width: 8cm,
      height: 1.75cm,
    ),
  ),
  align(horizon + center)[
    #figure(
      image("assets/tables/llvm_cov_table.png", width: 120%
      ),
      caption:[Simulador com 95% de cobertura de testes]
    )
    
  ],
)

= Resultados

== Com/Sem adaptação das capacidades

#figure(
  image("assets/plots/p_critico_travel_adapted_capacity.svg", width: 70%),
  caption: [ ($T_("amostragem")=100$, $eta=0.99$ )],
)

== Custo da Adaptação
#align(center)[
  
  #figure(
    image("assets/plots/p_critico_capacity_adapted_capacity.svg",height:95%),
     caption: [ ($T_("amostragem")=100$, $eta=0.99$ )],
  )  
]
= Conclusões

#bibliography("../zotero.bib")
