 #let titulo = "Otimização de redes complexas para o tráfego de pacotes por meio da adaptação da capacidade de transmissão dos seus elos"
#let nome_aluno="Vinícius Sousa Dutra"
#let orientador="Gonzalo Travieso"
#let cidade="São Carlos"
#let ano="2026"
#let tcc_generate_cover(
  body
) = {
  // Seções seguindo a ABNT
  show heading: it => {
    set text(size:12pt)
    set block(above: 2em, below: 1.5em)
    if it.level == 1 {
      text(weight: "bold")[#it]
    } else if it.level == 2 {
      text(weight: "bold")[#it]
    } else if it.level == 3 {
      text(weight: "bold")[#emph[#it]]
    } else if it.level==4 {
      text(weight: "regular")[#emph[#it]]
    }
    else {
      text(weight: "regular")[#it] 
    }
}
  set heading(numbering: "1.1 ")
  set math.equation(numbering: "(1)")
  set text(
    font: "Tinos",
    size: 12pt,
    hyphenate:false,
    lang: "pt",
    region: "br",
  )
  show footnote: it => it //panic("Não deve haver notas de rodapé") 
  set par(
    justify: true,
    leading: 0.65em
  )
  show figure: set par(leading: 0.35em)

 

  assert(
    not titulo.ends-with("."), 
    message: "Erro: O título do trabalho deve ser inserido sem ponto final."
  )

  align(center)[
    #text(size: 14pt)[#upper[
    UNIVERSIDADE DE SÃO PAULO \
    INSTITUTO DE FÍSICA DE SÃO CARLOS
    ]]
    #v(1fr) 
    #text(size:14pt)[#nome_aluno]
    #v(1fr)
    #text(size: 12pt)[#titulo]
    #v(1fr)
    #text(size: 14pt)[
        São Carlos \
       2026
    ]
  ]
  pagebreak()
  align(center)[
    #text(size:12pt)[
    Vinícius Sousa Dutra
  ] <label:capa>
]
  v(5fr) 

  align(center)[
    #text(size:12pt)[#titulo]
  ]

  v(1.5fr)

  
  align(right)[
    #box(width: 50%, align(left)[
      #set par(justify: true, leading: 0.35em) 
        #text(size:12pt)[
        Trabalho de conclusão de curso apresentado ao Instituto de Física de São Carlos da Universidade de São Paulo para obtenção do título de Bacharel em Física Computacional.
        Orientador: Prof. Dr. #orientador  - Instituto de Física de São Carlos
      ]
      
    ])
  ]

  v(4fr)

  align(center)[
    #cidade \
    #ano
  ]
  
  set page(
    paper: "a4",
    margin: (top: 3cm, bottom: 3cm, right: 2cm,left:2cm),
    footer: context {
    let intro_matches = query(<label:capa>)
    if intro_matches.len() > 0 {
      let intro = intro_matches.first()
      let current_page = here().page()
      let intro_page = intro.location().page()
      if current_page >= intro_page {
        set text(size: 10pt)
        let relative_page = (current_page - intro_page) + 1
        
        align(right)[
          #text(size:12pt)[#relative_page]
          ]
        }
      }
    }
  )
  body
}
