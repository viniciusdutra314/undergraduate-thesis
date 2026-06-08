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
#set text(lang: "pt", region: "br")
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
    - Grafo escolhido uniformemente no conjunto $cal(G)(n, m)$
    - Hipótese nula

  ]]],
  [#align(center)[#rect(width: 100%, height: 100%, stroke: 0.5pt + gray, radius: 3pt)[
    Geométrico (1961)
    #image("assets_slides/rgg.svg")
    - Nós distribuídos uniformemente em um espaço métrico
    - Arestas entre nós próximos
  ]]],
  [#align(center)[#rect(width: 100%, height: 100%, stroke: 0.5pt + gray, radius: 3pt)[
    Watts-Strogatz (1998)
    #image("assets_slides/watts.svg")
    - Um grafo regular com uma fração de arestas aleatórias
    - Mundo pequeno


  ]]],
  [#align(center)[
    #rect(width: 100%, height: 100%, stroke: 0.5pt + gray, radius: 3pt)[
      Barabási-Albert (1999)
      #image("assets_slides/barabasi.svg")

    ]
  ]],
)

== Tipos de roteamento


= Resultados

= Conclusões

#bibliography("../zotero.bib")
