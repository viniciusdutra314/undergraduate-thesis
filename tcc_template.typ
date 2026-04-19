#let tcc_generate_cover(
  body
) = {

  set heading(numbering: "1.1 ")
  set math.equation(numbering: "(1)")
  set text(
    font: "Times New Roman",
    size: 12pt,
    hyphenate:false,
    lang: "pt",
    region: "br",
  )

  set par(
    justify: true,
    leading: 0.65em
  )
  show figure: set par(leading: 0.35em)
  pagebreak()
  let date=datetime.today()
  let dict=(
    "1":"Janeiro",
    "2":"Fevereiro",
    "3":"Março",
    "4":"Abril",
    "5":"Maio",
    "6":"Junho",
    "7":"Julho",
    "8":"Agosto",
    "9":"Setembro",
    "10":"Outubro",
    "11":"Novembro",
    "12":"Dezembro"
  )  


  align(center)[
    #text(size: 14pt)[#upper[
    UNIVERSIDADE DE SÃO PAULO \
    INSTITUTO DE FÍSICA DE SÃO CARLOS
    ]]
    #v(1fr) 
    #text(size:14pt)[VINÍCIUS SOUSA DUTRA]
    #v(1fr)
    #text(size: 12pt)[Otimização de redes complexas para o tráfego de pacotes por meio de adaptação da capacidade de transmissão dos seus elos]
    #v(1fr)
    #text(size: 14pt)[
        São Carlos \
        #date.day()º de  #(dict.at(str(date.month()))) de #date.year()
    ]
  ]
  pagebreak()
  align(center)[
    #text(size:12pt)[
    Vinícius Sousa Dutra
  ]
]
  v(5fr) 

  align(center)[
    #text(size:12pt)[
    Otimização de redes complexas para o tráfego de pacotes por meio de adaptação da capacidade de transmissão dos seus elos]
  ]

  v(4fr)

  
  align(right)[
    #box(width: 50%, align(left)[
      #set par(justify: true, leading: 0.35em) 
        #text(size:12pt)[
        Trabalho de conclusão de curso apresentado ao Instituto de Física de São Carlos da Universidade de São Paulo para obtenção do título de Bacharel em Física Computacional.
      ]
      #v(0.5em)
      #text(size:12pt)[
        Orientador: Prof. Dr. Gonzalo Travieso - Instituto de Física de São Carlos
    ]
    ])
  ]

  v(4fr)

  align(center)[
    São Carlos \
    2026
  ]
  
  set page(
    paper: "a4",
    margin: (top: 3cm, bottom: 3cm, right: 2cm,left:2cm),
    header: context {
    let intro_matches = query(<text:introducao>)
    if intro_matches.len() > 0 {
      let intro = intro_matches.first()
      let current_page = here().page()
      let intro_page = intro.location().page()
      if current_page >= intro_page {
        set text(size: 10pt)
        let relative_page = (current_page - intro_page) + 1
        
        align(right)[
          #relative_page
          ]
        }
      }
    }
  )
    
  
  
  
  

  body
}
