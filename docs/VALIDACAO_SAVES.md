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
| Navegador Edge, IndexedDB e Godot Web | 12 verificações, 0 falhas |
| Regras Firestore no emulador | 10 subtestes aprovados, incluindo integração nativa |
| Cliente REST nativo dentro do emulador | 12 verificações, 0 falhas: CAS, multipartes, integridade e limpeza |

As sete suítes GDScript totalizam **128 verificações**. A integração REST é um
subteste da suíte do emulador, não dez testes adicionais de autenticação real.

Comandos e arquivos para reproduzir:

- `tools/validate-saves.ps1`: logs `.tools/save-suite-*.log`.
- `npm run test:rules`, com `GODOT_EXE` e Java 21: `.tools/firestore-validation.log`
  nesta execução; ambiente exige emulador e recusa acesso a produção.
- `tools/build-browser-fixture.ps1` + `tools/serve-web.mjs` +
  `tools/save-browser-validation.mjs`: `.tools/save-browser-results.json`.
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

Pendências: criação/configuração da base Firestore no projeto existente,
deploy revisado das regras/índices, login real e ida/volta em celular físico,
PC Web e Godot nativo. Os passos e o roteiro estão em
[Saves e sincronização](SAVES_E_SINCRONIZACAO.md). A ativação pública continua
desabilitada e não faz parte deste PR.
