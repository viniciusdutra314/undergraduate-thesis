#import "tcc_template.typ": tcc_generate_cover
#import "@preview/algorithmic:1.0.7": *

#{
  if sys.version!=version(0,14,2){
    panic("O documento foi feito em Typst 0.14.2, talvez não funcione em outra versão")
  }
}
#show: tcc_generate_cover.with()


#heading([Resumo],numbering: none
) <text:introducao>

= Introdução  
== E
= Materiais e Métodos 
= Resultados 
= Conclusões e considerações finais  

#pagebreak()
#bibliography("zotero.bib",
title:[Referências],
style: "associacao-brasileira-de-normas-tecnicas")

