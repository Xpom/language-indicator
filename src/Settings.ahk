; Настройки. Размеры и отступы — логические пиксели (для масштаба 100%).

DefaultSettings() {
    return {
        opacity: 85,        ; %
        pollMs: 50,
        caret: {
            enabled: true,
            side: "bottom", ; см. Core.Place
            gap: 3,
            size: 12,       ; высота флажка; ширина = высота * 4/3
        },
    }
}
