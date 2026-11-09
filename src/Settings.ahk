; Настройки. Размеры и отступы — логические пиксели (для масштаба 100%).

DefaultSettings() {
    return {
        opacity: 85,        ; %
        pollMs: 50,         ; опрос каретки и раскладки
        mousePollMs: 15,    ; опрос курсора: флажок у мыши должен поспевать за ней
        caret: {
            enabled: true,
            side: "bottom", ; см. Core.Place
            gap: 3,
            size: 12,       ; высота флажка; ширина = высота * 4/3
        },
        mouse: {
            enabled: true,
            side: "bottom-right",
            gap: 3,
            size: 12,
        },
    }
}
