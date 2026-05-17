#import "main.typ" as tcc
#import "tcc_template.typ" as tcc_template
#import "@preview/polylux:0.4.0"
#import "@preview/diatypst:0.9.1": *
#import "@preview/diagraph:0.3.7"
#{
  if sys.version!=version(0,14,2){
    panic("O documento foi feito em Typst 0.14.2, talvez não funcione em outra versão")
  }
}
#set text(lang: "pt",region: "br")
#show: slides.with(
  title: [#tcc_template.titulo],
  subtitle: "easy slides in typst",
  date: "01.07.2024",
  authors: ([#tcc_template.nome_aluno].text),
  count:"number",
  ratio: 16/9,
  layout: "medium",
  title-color: blue.darken(60%),
  toc: true,
)



= O que é um grafo?


== Tipos de grafos


/ *Grafo*: #tcc.definição_grafo

#align(center)[
  #diagraph.render(```
    graph RedeSocial {
      node [style=filled, fillcolor=lightblue];
      rankdir="LR"
      "Alice" -- "Bob";
      "Alice" -- "Carlos";
      "Bob" -- "Daniela";
      "Carlos" -- "Daniela";
      "Daniela" -- "Eduardo";
      "Eduardo" -- "Alice";
  }
  ```.text,width:50%)
]
/ *Digráfo*: #tcc.definição_digrafo

#figure(
  align(center)[
  #diagraph.render(```
  digraph ScientificPython {
    // Estética geral
    node [shape=box, style="filled, rounded", fontname="Verdana", fillcolor="#f9f9f9"];
    edge [color="#555555", arrowhead=vee];
    rankdir=LR; // Faz o grafo crescer de baixo para cima (NumPy na base)

    // Bibliotecas
    "NumPy" [fillcolor="#4D77CF", fontcolor=white];
    "SciPy" [fillcolor="#8CAAE6"];
    "Pandas" [fillcolor="#E70488", fontcolor=white];
    "Matplotlib" [fillcolor="#113137", fontcolor=white];
    "Scikit-Learn" [fillcolor="#F7941E"];
    "Igraph"
    // Relações de Dependência
    "SciPy" -> "NumPy";
    "Pandas" -> "NumPy";
    "Matplotlib" -> "NumPy";
    "Scikit-Learn" -> "NumPy";
    "Scikit-Learn" -> "SciPy";
    "Código Python" -> "Igraph"
    // Aplicação final
    "Código Python" [shape=ellipse, fillcolor="#2ecc71"];
    "Código Python" -> "Scikit-Learn";
    "Código Python" -> "Pandas";
}
```.text,width:47%)
],caption: [Dependências simplificadas de um código Python]
  
)

/ *Grafo Ponderado*: #tcc.definição_grafo_ponderado

#align(center)[
#diagraph.render(```
  digraph Logistica {
    rankdir=LR;

    "SP" -> "RJ" [label="434 km"];
    "SP" -> "MG" [label="903 km"];
    "MG" -> "RJ" [label="773 km"];
    "MG" -> "ES" [label="R 300"];
    "RJ" -> "ES" [label="R 250"];
    "ES" -> "SP" [label="R 450"]; 
}
```.text,width:60%)
]
#bibliography("zotero.bib")