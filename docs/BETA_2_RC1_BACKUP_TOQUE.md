# Candidata 0.9.1-beta.2-rc.1 — backup próprio e inventário por toque

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

Os resultados automatizados/emulados e a publicação serão acrescentados abaixo.
Não há aprovação física presumida nem nova campanha completa nesta rodada.
