# Evidências de validação — 14/10/2026

Revisão anterior investigada: `e89b0ed`. Dados gerados nos diretórios `.tools/`,
perfil de navegador exclusivo e emuladores `demo-tece-island`. Saves reais de
jogadores, regras do projeto real e faturamento não foram alterados.

| Validação | Resultado |
| --- | --- |
| Reprodução no checkout anterior | 3 riscos reproduzidos: catálogo oculta save intacto, escrita local antiga sobrescreve e ausência retorna estado vazio |
| Catálogo e migração de mundos | 19 verificações, 0 falhas |
| Progresso separado por conta / I/O | 21 verificações, 0 falhas |
| Lobby, logout e resolução de disputa local | 10 verificações, 0 falhas |
| Saves órfãos, backups, versões divergentes e recuperação | 20 verificações, 0 falhas |
| Sincronização com transporte controlado | 22 verificações, 0 falhas |
| Baús, armas e restauração de saves | 26 verificações, 0 falhas |
| Regressão de autenticação obrigatória | 10 verificações, 0 falhas |
| Piloto: renovação após confirmar e-mail, erros e diagnóstico | 13 verificações, 0 falhas |
| Troca de aparelho, lobby, avanço remoto limpo e alterações durante a rede | 14 verificações, 0 falhas |
| Navegador Edge, IndexedDB e Godot Web | 12 verificações, 0 falhas |
| Pacote Web do piloto, PC/mobile emulado, falha de rede e download incompleto | 12 verificações, 0 falhas |
| Endereço privado atualizado, versão do pacote e autenticação negativa | 3 verificações, 0 falhas |
| Regras Firestore no emulador | 10 subtestes aprovados, incluindo integração nativa |
| Cliente REST nativo dentro do emulador | 12 verificações, 0 falhas: CAS, multipartes, integridade e limpeza |

As nove suítes GDScript totalizam **155 verificações**. A integração REST é um
subteste da suíte do emulador, não dez testes adicionais de autenticação real.

Comandos e arquivos para reproduzir:

- `tools/validate-saves.ps1`: logs `.tools/save-suite-*.log`.
- `npm run test:rules`, com `GODOT_EXE` e Java 21: `.tools/firestore-validation.log`
  nesta execução; ambiente exige emulador e recusa acesso a produção.
- `tools/build-browser-fixture.ps1` + `tools/serve-web.mjs` +
  `tools/save-browser-validation.mjs`: `.tools/save-browser-results.json`.
- `tools/export-sync-test.ps1` + `tools/package-sync-pilot.mjs` +
  `tools/sync-pilot-browser-validation.mjs --live-invalid`:
  `.tools/sync-pilot-browser-results.json`. Usa contas inválidas para a prova
  negativa de autenticação; não há sessão positiva simulada no piloto hospedado.
- `tests/audit_save_loss_baseline.gd` somente no checkout anterior isolado:
  `.tools/baseline-save-loss.log`.

Mundo inicial: 12.066 bytes de JSON / 3.352 bytes deflate-base64. Mundo com 100
baús abastecidos e equipamentos: aproximadamente 65 KiB de JSON / 4,8 KiB
deflate-base64. Ambos usam uma parte. Cada execução imprime a medição atual;
uma fixture incompressível também atravessa o Firestore em múltiplas partes.

O navegador foi recarregado, fechado e reaberto em perfil próprio. Duas abas
disputaram o mesmo save; a antiga foi recusada e seu candidato preservado.
O fluxo Godot Web também escreveu, importou legado uma vez e releu contas
separadas depois de reload. Nenhum armazenamento do perfil pessoal foi limpo.

Os logs locais do Godot podem incluir a restrição do sandbox ao repositório de
certificados do Windows. Os testes REST de integração usam HTTP apenas no
emulador local. Isso não valida TLS/login Firebase em uma instalação nativa real.

Piloto privado publicado em 14/10/2026, com configuração habilitada apenas para
as duas contas de teste informadas. Deploy Sites confirmado com status
`succeeded`, versão 1. Código do jogo compilado: `e88d055`; pacote hospedado:
`99cb051cb01b17fff446caa51dca95ed62095c62`. A hospedagem separada usa origem própria;
nenhum save do site público foi movido ou apagado.

Atualização da correção de troca: versão Sites 2 confirmada (`succeeded`), mesmo
endereço privado e mesma origem IndexedDB. Jogo `0.8.1-sync-pilot.2`, compilado
da revisão `5af37a6dfbd0d09068e9e7f4e357ad1d2fe25c53`; pacote hospedado
`120026e06aa25d014f12d6f318677e4f3e4298d4`. As 155 verificações Godot, 10
subtestes de regras (incluindo 12 verificações REST) e 12 verificações Web do
pacote atualizado passaram nesta execução. O CI da correção também passou.
Após o deploy, o Edge confirmou carregamento, versão/commit dentro do pacote
servido e rejeição de credenciais inválidas na origem HTTPS do piloto.

Backend Firebase real: credenciais inválidas rejeitadas corretamente no Godot
nativo e na exportação Web, inclusive a partir do endereço HTTPS publicado.
O teste desse endereço usou somente acesso privado da hospedagem em memória,
enviado exclusivamente ao domínio do Site, nunca ao Firebase. Isso comprova
a configuração básica de autenticação,
sem comprovar login positivo, verificação de e-mail ou regras remotas das contas reais.

O responsável confirmou ida/volta PC → celular → PC ao escolher a versão da
nuvem, com o progresso correto. Um conflito apareceu e a existência de mudanças
locais ainda não foi confirmada. Reproduzido separadamente um conflito falso no
caminho de envio de snapshot limpo (e registro obsoleto depois do download);
14 testes de regressão agora passam, incluindo alterações independentes.
Detalhes e reteste no documento do piloto. A suíte de regras foi repetida:
10 subtestes aprovados, com 12 verificações REST nativas incluídas.

Pendências: conferir a troca com cópia local limpa no novo piloto, isolamento
de duas contas e fechar/reabrir com contas reais (ainda não confirmados pelo
responsável), índices, Godot nativo e migração real usando cópias próprias.
O roteiro está em [Piloto de sincronização](PILOTO_SINCRONIZACAO.md).
A ativação pública continua desabilitada e não faz parte deste PR.
