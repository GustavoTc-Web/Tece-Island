# Candidata 0.9.1-beta.2-rc.1 — backup próprio e inventário por toque

Registro histórico da candidata. O usuário posteriormente relatou que os ajustes
funcionaram e autorizou a [publicação oficial 0.9.1-beta.2](PUBLICACAO_0_9_1_BETA_2.md).
O relato não especifica campanha completa, aparelho ou todos os casos físicos.

Branch `release/solo-beta.2-rc.1`, preparada em 02/11/2026. Dois ajustes pontuais;
save **v9**, campanha **v2**, tarefas **v2** e demais mecânicas preservados.
O endereço oficial mantém **0.9.1-beta.1** até autorização posterior. Não há
merge na main, nova tag oficial ou mudança no Firebase nesta rodada.

## Backup dos meus mundos

No lobby, **Menu → Exportar backup dos meus mundos**. A explicação ao lado
informa que o arquivo contém progresso e nomes definidos pelo jogador e deve
ser guardado como **backup privado**. Download `tece-island-meus-mundos.json`,
envelope `format:2`, `scope:current-account-worlds`, origem, data e entradas.
Não é um relatório anonimizado para suporte.

A seleção usa a sessão Firebase atual verificada no Godot. O JavaScript não
recebe UID, senha ou token para escolher a conta. Sessão ausente/expirada ou
alterada durante a leitura cancela a exportação; sem login o botão não aparece.

Critérios explícitos:

1. Ler somente `account/<SHA256 do UID atual>/`, nunca uma varredura global.
2. Aceitar somente catálogo `worlds` e `world/<ID seguro>`, com as classes de
   cópia reconhecidas: backup/backup-2, migrações v5–v9/campanha, antes da nuvem,
   conflitos e originais preservados de recuperação/resolução. Sufixos aleatórios
   dessas classes têm o formato de 32 caracteres hexadecimais do produtor Web.
3. Exigir JSON legível, proprietário exatamente igual ao UID da sessão e, para
   saves, ID interno igual ao da chave, versão compatível e SaveValidation válido.
4. Validar campos e tipos reconhecidos também dentro de inventários, campanha,
   estruturas, loot e metadados. Entradas com campos desconhecidos, dados Auth,
   anexos opacos/Base64 ou tipos incompatíveis ficam de fora. Não copiar texto
   cru com membros JSON duplicados ignorados pelo parser; serializar o objeto
   validado, preservando estado e hashes canônicos.
5. Manter no catálogo somente referências com ao menos uma cópia própria elegível.
   Excluir histórico de servidores da cópia exportada, pois não é necessário à
   recuperação de mundos. O catálogo original não é alterado.

Entradas de outra conta não entram como saves, catálogos, backups, conflitos,
nomes, UIDs ou hashes de conta. Dados locais legados sem ID/dono, ilegíveis,
classes de preservação desconhecidas e registros suspeitos são excluídos do
arquivo padrão. **Permanecem intactos no navegador.** Uma mensagem informa
quando algum registro/referência da conta ficou fora, sem revelar identificadores.

## Recuperação dos dados excluídos e de uma cópia válida

- Use o mesmo endereço, perfil, navegador e conta originais. Não limpe dados do
  site, não reatribua UID/ID e não edite o número da versão do save.
- As cópias reconhecidas continuam disponíveis na recuperação já existente no
  lobby. Para save legado, a importação antiga continua separada e confirmada;
  não há associação automática de dados sem dono à conta atual.
- Se o registro ficou fora por estar ilegível, sem dono ou conter campos não
  reconhecidos, preserve primeiro o perfil/IndexedDB e procure recuperação
  técnica com o titular. Identifique a propriedade por evidências, trabalhe em
  cópia, valide com cliente v9 e só então escolha a recuperação explícita. Não
  descarte ou sobrescreva a entrada original para fazer o backup "passar".
- O [procedimento técnico legado](RECUPERAR_MUNDO.md) pode abranger outras contas;
  seu resultado é privado e exige o cuidado/consentimento dos titulares. Não é
  o botão padrão nem uma alternativa geral sem login.
- Não foi criado um botão novo de importação de arquivo. A restauração técnica
  foi exercitada com a cópia baixada em outro perfil descartável: reinserção
  controlada das chaves próprias e abertura normal no cliente v9. O teste nativo
  também escreve/lê a cópia por AccountProgress e reabre o mundo real.
- **0.9.0 não abre v9.** Use o [procedimento compatível](RECUPERACAO_BETA_V9.md).

## Arrasto no inventário

Segurar um item imóvel por **350 ms** inicia a prévia. Ela acompanha o dedo e
o destino visível recebe destaque. Soltar move a pilha inteira para vazio ou
troca com ocupado, usando o mesmo `swap_slots` do mouse. Deslizar mais de 10 px
CSS antes da espera fixa o gesto como rolagem, mesmo se continuar segurando.

Soltar fora, cancelar o toque, perder foco, fechar o painel ou mudar seu tamanho
cancela sem jogar itens. Um segundo dedo cancela com segurança. O Web trata
`touchcancel`/`pointercancel` antes da soltura entregue pelo Godot; essa diferença
foi encontrada e corrigida na emulação. O destaque preserva a legibilidade dos
ícones/nomes, sem revelar o texto duplicado do botão.

O mouse continua usando o drag-and-drop nativo; **Mover / trocar** continua
disponível no toque. Quantidades, UID de arma, munição, água, equipamento,
seleção, barra rápida e ordem após salvar/reabrir são preservados. Os toques
do painel não são convertidos em mouse, movimento ou ataque do personagem.

## Organização e reteste

- Exportação: branch `fix/account-save-export`, commits `25a567d` e `0a0f94b`.
- Toque: branch `fix/inventory-touch-drag`, commits `d07e914`, `06d103f`, `50be6ad`.
- Candidata combina os commits e acrescenta identificação, testes e este registro.
  Nenhuma dessas branches substitui a main.

Roteiro físico com **mundo novo de teste**:

1. No celular, confirme a versão, segure a espada no slot 7 e arraste ao 1 ocupado;
   espere troca completa e barra/equipamento correspondentes. Repita para vazio.
2. Solte fora; interrompa um toque; feche o inventário ou suspenda o aplicativo
   durante o gesto. Espere cancelamento sem perda e sem ataque ao retornar.
3. Deslize para rolar antes de segurar. Use também Mover/trocar. No PC, repita o
   arrasto com mouse. Salve, volte ao lobby, feche/reabra e confira ordem/atributos.
4. Em perfil com duas contas **de teste**, exporte conectado como A e depois B:
   cada arquivo deve conter somente seus mundos e cópias reconhecidas. Sem login,
   não deve haver opção de exportação. Guarde os arquivos como backups privados.

## Resultado técnico e publicação

**Publicada privadamente em 02/11/2026 às 11:17 BRT**:
[abrir candidata](https://tece-island-solo-beta.gustavotccandido.chatgpt.site/Tece-Island/).
Versão **0.9.1-beta.2-rc.1**, jogo congelado em
`2738a9f49fb5d390fdb6bbcfec06e2af54aeb358`. Site versão interna **3**, fonte
`bedcd988986accb7ef95e874d7bdf2f279f4fad6`; deploy
`appgdep_6ae89b6d17d481919329edf4a7343222` **succeeded**.
PCK servido SHA-256:
`09ffe124a0d85d0fd8deed91630f600378d8a7adf92368647190e98d5d33e948`.

- **211 checks Godot em dez suítes**, sem falhas. Inclui 36 checks do exportador,
  13 do toque, recuperação real v9, backups, catálogos, sync, Auth e controles.
- **Oito testes de configuração** passaram; regras e permissões Firebase não
  foram aplicadas ou ampliadas.
- **23 checks Web de inventário**: mouse e toque CDP emulado, prévia/destino,
  espada 7→1, vazio/ocupado, atributos, cancelamento fora/OS/foco/fechamento/
  resize, rolagem, alternativa Mover/trocar, controles e IndexedDB/reabertura.
- **27 checks Web de backup**, no cliente completo com Auth simulado somente
  no transporte do navegador: A e B no mesmo perfil, cópias de migração/conflito,
  registros opacos/ilegíveis/sem dono preservados fora da cópia, referências
  estrangeiras no catálogo rejeitadas, ausência de credenciais, recusa sem login
  e restauração do arquivo baixado em outro perfil descartável com cliente v9.
- PCK abriu em projeto vazio com versão/commit/schema corretos, mesmas duas
  contas e ausência de fixtures/regras administrativas. O manifesto e os 19
  arquivos declarados foram conferidos no Site servido; HTML preserva a fonte
  integral com a inserção do provedor. Os 38 hashes de fontes correspondem ao
  commit congelado. O carregamento inicial privado foi conferido nos formatos
  PC/mobile emulados, sem login de produção e com exportação sem login recusada.

**Limitação da conferência privada:** a sessão headless autorizada por cabeçalho
de QA recebeu HTTP **401** ao carregar `index.audio.worklet.js` e
`index.audio.position.worklet.js`. Os mesmos arquivos foram obtidos e conferidos
por hash na consulta HTTP autorizada; o cliente chegou à tela de login. Isso
registra um limite desse acesso automatizado, não uma aprovação de áudio nem
uma conclusão sobre o comportamento da sessão normal do usuário. Áudio no Site
privado requer reteste autenticado no aparelho. Não foi feita alteração nos
módulos ou nas permissões para contornar isso. Os erros constam integralmente,
sem credenciais, em `published-startup.json`.

[Resultados e capturas](validation/beta.2-rc.1/),
[publicação](validation/beta.2-rc.1/deployment.json),
[oficial preservada](validation/beta.2-rc.1/official-preserved.json).

**Estado real:** os dois ajustes estão implementados e publicados **somente
nesta candidata privada**. A oficial continua 0.9.1-beta.1, commit `fbc56f7`, main
`2d7cd6c`; portanto ainda contém o exportador geral antigo até promoção
autorizada. Não compartilhe o arquivo antigo como se fosse restrito à conta.
Firebase, administradores, listas de chat/sync, faturamento, saves reais e
alteração local do IDE foram preservados. Multiplayer segue adiado.

**Pendências:** confirmação física do usuário no PC/celular, incluindo o gesto
real e suspensão/retomada. Os testes acima são automações/cenários preparados,
não uma partida humana. Não há aprovação física presumida nem nova campanha
completa nesta rodada; a exploração pelo controlador continua não executada.
