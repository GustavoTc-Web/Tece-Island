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
| Navegador Edge, IndexedDB e Godot Web | 12 verificações, 0 falhas |
| Pacote Web do piloto, PC/mobile emulado, falha de rede e download incompleto | 12 verificações, 0 falhas |
| Endereço privado publicado e autenticação negativa na origem do piloto | 2 verificações, 0 falhas |
| Regras Firestore no emulador | 10 subtestes aprovados, incluindo integração nativa |
| Cliente REST nativo dentro do emulador | 12 verificações, 0 falhas: CAS, multipartes, integridade e limpeza |

As oito suítes GDScript totalizam **141 verificações**. A integração REST é um
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

Backend Firebase real: credenciais inválidas rejeitadas corretamente no Godot
nativo e na exportação Web, inclusive a partir do endereço HTTPS publicado.
O teste desse endereço usou somente acesso privado da hospedagem em memória,
enviado exclusivamente ao domínio do Site, nunca ao Firebase. Isso comprova
a configuração básica de autenticação,
sem comprovar login positivo, verificação de e-mail ou regras remotas das contas reais.

Pendências: o responsável informou base `(default)` e regras publicadas.
Ainda faltam conferir índices, permissões com login positivo, ida/volta em
celular físico/PC Web/Godot nativo e migração real usando cópias próprias.
O roteiro está em [Piloto de sincronização](PILOTO_SINCRONIZACAO.md).
A ativação pública continua desabilitada e não faz parte deste PR.
