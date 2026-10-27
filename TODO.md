# TikTok LIVE Arena — entregas

## Entregue: arena e identidade visual

- Arena futurista 2D com arquibancadas, telões, iluminação, profundidade e atmosfera.
- Identidade visual original em português do Brasil, sem copiar personagens, logotipos ou artes protegidos.
- Seis lutadores visualmente distintos: Capitão Brasa, Raio Azul, Sombra Negra, Guardião Dourado, Lula e Flávio Bolsonaro. Lula e Flávio Bolsonaro são avatares fictícios e satíricos de jogo, sem slogans, logotipos ou afirmações sobre a vida real.
- Tela inicial com seleção de lutadores, iniciar jogo, configurar arena, modo demonstração, conexão TikTok LIVE, modo transmissão e estado visível da integração.
- HUD responsivo com nomes, vida, energia, rodada, cronômetro, placar, especial, histórico e eventos de torcida.

## Entregue: combate automático

- Motor real de combate em tempo real com aproximação e recuo, ataque, defesa, esquiva, dano baseado em atributos, críticos, combos, energia, recargas e especiais.
- Rodadas configuráveis, pausa, reinício, vitória, derrota, empate, histórico e reinício automático opcional.
- Animações visíveis de ataque, dano, esquiva, defesa, especial, vitória/derrota por estado e efeitos visuais de impacto.

## Entregue: presentes e demonstração

- Rosa, Coração, Foguete e Coroa com regras observáveis e configuração centralizada.
- Identificação de usuário, presente, quantidade, alvo e efeito no histórico.
- Deduplicação por ID, limites, validação de payload e multiplicador de repetição em janela controlada.
- Modo Demonstração explicitamente marcado; nenhum evento simulado é apresentado como conexão TikTok real.

## Entregue: transmissão e qualidade

- Modo de transmissão/OBS sem controles administrativos, com composição horizontal e vertical.
- Loading screen específico do jogo, Retry e progresso real de download.
- Testes nativos para catálogo, combate, presentes, deduplicação, integração bloqueada e ativos.
- Capturas nativas revisadas em desktop e vertical; build Web e pacote exportado validados.

## Pendente antes de produção TikTok LIVE

- Backend autorizado usando somente documentação/API oficial ou integração autorizada pelo TikTok.
- Segredos exclusivamente no servidor; validação de assinatura, usuário, presente, quantidade e ID; reconexão e logs sem credenciais.
- WebSocket/estado oficial multi-cliente e autenticação server-side do painel administrativo.
- Teste end-to-end em ambiente autorizado antes de marcar o adaptador como conectado.
