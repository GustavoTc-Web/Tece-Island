# Campanha exploratória da RC2 — ciclo do controlador encerrado

**Campanha exploratória não executada por limitação da ferramenta.**

Consolidação de 01/11/2026: o usuário já havia relatado login concluído e jogo
no lobby. Esse relato registra autenticação informada pelo usuário, sem aprovar
gameplay. Nas tentativas posteriores, a janela foi identificada como TC Island,
mas reportada como minimizada; a restauração voltou a encerrar o controle por
falta de confirmação segura da URL.

Em 01/11, a revisão automática rejeitou a identificação da janela por considerá-la
repetição do ciclo que o usuário pediu para encerrar. Não houve nova tentativa
nem método alternativo para contornar essa rejeição. O ciclo está **encerrado**;
não se pede mais restauração ou login para finalizar o trabalho independente.

Parada exata: antes de criar mundo exploratório e antes de qualquer ação de
gameplay. Nenhum dia, coleta, morte, vitória ou Continuação foi executado pelo
controlador. Nenhum atalho foi usado para forçar progresso. O relato humano do
piloto anterior e os cenários técnicos não aprovam a campanha na RC2.

Versão congelada: **0.9.1-beta-rc.2**, jogo
`7c254c1f8454d768228c171cf6fa040b5eb322dc`.
Site privado publicado em 31/10/2026, versão interna 2. O cliente servido teve
manifesto e 19 arquivos conferidos por hash. Não houve mudanças de código do jogo
depois desse congelamento; os commits seguintes só finalizam testes e registros.

## Registro inicial de 31/10, preservado como histórico

Ambiente: Windows, janela separada do Edge com perfil de teste dentro de
`.tools/exploratory-edge-profile`, endereço solicitado:
https://tece-island-solo-beta.gustavotccandido.chatgpt.site/Tece-Island/ .

Foi aberta uma janela que o inventário identificou como
`É necessário entrar - Perfil 1`. Na tentativa de obter seu estado, o controlador
encerrou o Computer Use com o motivo:

> could not determine the current browser URL on Windows with enough confidence to enforce policy

No registro inicial: uma tentativa de captura, um encerramento. O controlador não
devolveu captura da página ou estado suficiente para iniciar ações. A orientação
da skill exige interromper entradas quando o controle termina; nenhum método
alternativo foi usado para contornar a proteção.

Classificação: **limitação da ferramenta antes do login**, não um defeito de
campanha demonstrado. Não houve login positivo de produção, criação de mundo
exploratório, dia jogado, morte/nova tentativa, vitória ou Continuar explorando
nesta rodada. A causa interna da falha de reconhecimento da URL não foi
diagnosticada. Nenhuma senha/token foi solicitado ou registrado.

O pedido inicial de login/restauração foi substituído pelo encerramento acima.
A continuação agora é o [reteste manual](RETESTE_MANUAL_RC2.md), com mundo novo,
controles normais e resultados esperados. O usuário pode fornecer o percurso
completo sem depender de novas tentativas do controlador. Novos bugs aguardam
sua avaliação, sem correção automática. [Fechamento](FECHAMENTO_BETA_SOLO_RC2.md).

## Bugs adicionais da rodada

**Nenhum bug adicional de jogabilidade foi confirmado: a rodada não começou.**
Não há evidência para aprovar uma campanha completa ou afirmar ausência de bugs.
As verificações preparadas de templos, sono, morte, reabertura e vitória são
testes técnicos separados; não substituem esse percurso.

Quando a rodada puder ocorrer, cada ocorrência deve registrar versão/ambiente,
dia/etapa, passos, esperado/observado, impacto, evidência/frequência e hipótese
separada de causa confirmada. Problemas adicionais aguardam avaliação do usuário;
não serão corrigidos automaticamente após encontrá-los.

## Limites dos resultados entregues

Confirmados por automação: os cinco ajustes solicitados, migração de cópias,
persistência, regras de chat no emulador e integridade do pacote privado.
Preparação das regras/configurações Firebase concluída; aplicação remota e
abertura a novas contas pendentes. Não há acesso administrativo ativo na CLI.

Permanecem físicos: campanha completa desta RC2, sensação de controle/desempenho,
som audível, teclado do aparelho, rotação e suspensão/retomada reais; casas/templos
e organização do inventário nos aparelhos do usuário. Nenhum desses itens foi
marcado como aprovado nesta revisão.
