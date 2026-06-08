#import "main.typ" as tcc
#import "tcc_template.typ" as tcc_template
#import "@preview/polylux:0.4.0"
#import "@preview/diatypst:0.9.1": *
#import "@preview/diagraph:0.3.7"
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
  subtitle: "easy slides in typst",
  date: "01.07.2024",
  authors: ([#tcc_template.nome_aluno].text),
  count: "number",
  ratio: 16 / 9,
  layout: "medium",
  title-color: blue.darken(60%),
  toc: true,
)

= Introdução

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

  figure(caption: "Comparação dos comprimentos dos roteamentos em um quadrado 20 x 20")[
    #image("assets_slides/modelos_roteamento.svg")

  ],
)
= Resultados

= Conclusões

#bibliography("../zotero.bib")
