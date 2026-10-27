# TikTok LIVE Arena

Jogo web 2D de batalha automática para transmissões ao vivo. A versão atual entrega uma arena funcional local, seis lutadores originais ou satíricos gerados para o projeto, combate automático por regras, presentes simulados, histórico local e modo de transmissão limpo para captura no OBS.

## Executar localmente

Pré-requisitos: Godot 4.7.2 com export templates Web, Node.js e npm. No diretório do projeto:

```bash
npm run check
npm run preview:build
npm run dev
```

O modo demonstração não precisa de credenciais, servidor externo ou conta TikTok. Para validar o pacote:

```bash
npm run check -- --pack
npm run build
```

## Como jogar

1. Na tela inicial, selecione um lutador para cada lado.
2. Clique em **Iniciar jogo** ou **Modo demonstração**.
3. O combate é automático: os lutadores se aproximam, atacam, defendem, esquivam, acumulam energia, usam especiais, pontuam rodadas e chegam a vitória, derrota ou empate.
4. Durante a partida, escolha o alvo e use Rosa, Coração, Foguete ou Coroa. Esses eventos são simulados e aparecem como `DEMO` no histórico.
5. Use Pausar, Reiniciar ou Sair. O histórico é persistido em `user://livearena_history.json`.

## OBS Studio

Clique em **Abrir modo transmissão**. O modo oculta controles administrativos e mostra apenas arena, HUD, placar, vida, energia, rodada e histórico. No OBS, adicione uma **Fonte de navegador** usando a URL do preview/publicação e ajuste para 1920×1080. Para live vertical, use 1080×1920; o layout responsivo reorganiza os lutadores e mantém o HUD legível.

## Arquitetura

- `scripts/main.gd`: telas, HUD responsivo, animações, modo transmissão e persistência local.
- `scripts/game/combat_engine.gd`: estado autoritativo local, atributos, dano, críticos, especiais, rodadas e resultados.
- `scripts/integration/gift_manager.gd`: catálogo, validação, limites, deduplicação e multiplicadores.
- `scripts/integration/tiktok_live_adapter.gd`: adaptador isolado com estado honesto de conexão.
- `scripts/effects/arena_fx.gd`: efeitos visuais de impactos, especiais e presentes.
- `test/test_suite.gd`: verificações automatizadas do loop, presentes, integração e ativos.
- `assets/livearena/`: arte original dos seis lutadores e da arena futurista.

O elenco inclui Capitão Brasa, Raio Azul, Sombra Negra, Guardião Dourado, Lula e Flávio Bolsonaro. Os dois últimos são apresentados como avatares fictícios e satíricos de jogo, sem slogans, logotipos ou afirmações sobre a vida real.

## Integração TikTok LIVE

A integração real **não está concluída nesta versão**. O botão **Conectar TikTok LIVE** mostra `indisponível` e bloqueia eventos reais porque nenhum backend autorizado foi configurado. Para concluir essa etapa, será necessário um serviço de servidor autorizado que use somente documentação/API oficial ou integração autorizada pelo TikTok, mantenha tokens exclusivamente no servidor, valide assinatura/usuário/presente/quantidade/ID, encaminhe eventos para o adaptador com IDs estáveis e trate desconexão/reconexão. Não há endpoint, token ou método privado embutido no navegador.

Até que essa ponte exista, o jogo permanece explicitamente no modo demonstração e não simula uma conexão real.

## Limites conhecidos

O painel administrativo atual é local e serve para configurar duração e reinício da demonstração. Autenticação server-side, estado oficial multi-cliente e WebSocket de produção dependem da ativação posterior de um backend. A versão atual foi construída para permitir testes locais seguros sem simular a conexão TikTok.
