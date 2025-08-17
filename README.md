# 🍔 Simulador de Restaurante

Un juego de simulación de restaurante desarrollado en **Godot 4.4** donde el jugador gestiona un restaurante, atiende clientes, prepara pedidos y administra recursos en un entorno 3D.

## 📋 Descripción del Proyecto

Platform3D es un juego de gestión de restaurante en tercera persona donde los jugadores deben:
- Atender clientes y tomar pedidos
- Preparar diferentes tipos de comida siguiendo recetas
- Gestionar el tiempo y los recursos eficientemente
- Progresar a través de múltiples niveles de dificultad
- Mantener un balance financiero positivo

## 🎮 Características del Juego

### 🎯 Mecánicas Principales
- **Sistema de pedidos dinámico**: Los clientes llegan y realizan pedidos de diferentes comidas
- **Preparación de comida**: Sistema de recetas con diferentes ingredientes y tiempos de preparación
- **Gestión de tiempo**: Días de trabajo con diferentes fases (mañana, hora pico, tarde)
- **Sistema de niveles**: Progresión basada en eficiencia y objetivos de dinero
- **Reserva de mesas**: Sistema avanzado de gestión de mesas y clientes

### 🍽️ Tipos de Comida
- Hamburguesas (básica, completa, especial)
- Pizzas (margherita, pepperoni, hawaiana)
- Ensaladas (césar, griega, mixta)
- Bebidas (agua, refrescos, café)
- Postres (helados, pasteles)

### 📊 Sistema de Progresión
- **Nivel 1**: Principiante (40% eficiencia, $200 objetivo)
- **Nivel 2**: Experimentado (60% eficiencia, $350 objetivo)
- **Nivel 3**: Experto (75% eficiencia, $500 objetivo)

## 🛠️ Tecnologías Utilizadas

- **Motor**: Godot 4.4
- **Lenguaje**: GDScript
- **Gráficos**: 3D con Forward Plus rendering
- **Audio**: Sistema de música dinámica
- **Assets**: KayKit Restaurant Bits, KayKit City Builder Bits, Kenney Mini Characters

## 📁 Estructura del Proyecto

```
📦 platform3d/
├── 📜 project.godot              # Archivo principal del proyecto
├── 📁 scripts/                   # Scripts de lógica del juego
│   ├── 🎮 GameManager.gd         # Gestor principal del juego
│   ├── 👤 player.gd              # Control del jugador
│   ├── 🏪 cliente.gd             # Lógica de clientes
│   ├── 📋 HudController.gd       # Control de interfaz
│   └── ...
├── 📁 data/                      # Datos del juego
│   ├── 📄 recetas.json          # Definición de recetas
│   └── 📄 recetas1.json         # Recetas adicionales
├── 📁 Hud/                       # Interfaz de usuario
├── 📁 audio/                     # Música y efectos de sonido
├── 📁 Main_menu/                 # Menú principal
├── 📁 Menu_pausa/                # Menú de pausa
└── 📁 addons/                    # Complementos y assets externos
```

## 🚀 Cómo Ejecutar el Proyecto

### Prerrequisitos
- **Godot 4.4** o superior
- Sistema operativo: Windows, macOS, o Linux

### Instalación
1. Clona este repositorio:
   ```bash
   git clone [URL_DEL_REPOSITORIO]
   ```

2. Abre Godot Engine

3. Importa el proyecto seleccionando el archivo `project.godot`

4. Ejecuta el proyecto presionando **F5** o el botón "Play"

## 🎯 Controles del Juego

### Movimiento
- **WASD**: Mover el personaje
- **Mouse**: Mirar alrededor
- **Shift**: Correr
- **Espacio**: Saltar

### Interacciones
- **Click Izquierdo**: Interactuar con objetos
- **E**: Agarrar/Soltar objetos
- **Tab**: Abrir inventario
- **Esc**: Menú de pausa

## 🎨 Assets y Recursos

### Modelos 3D
- **KayKit Restaurant Bits**: Elementos de restaurante
- **KayKit City Builder Bits**: Elementos urbanos
- **Kenney Mini Characters**: Personajes

### Audio
- Música de ambiente (Jazz In Paris)
- Efectos de sonido para interacciones

## 🔄 Sistema de Juego

### Flujo de Juego
1. **Inicio del día**: Los clientes comienzan a llegar
2. **Toma de pedidos**: Interactúa con clientes para recibir pedidos
3. **Preparación**: Recolecta ingredientes y prepara la comida
4. **Entrega**: Sirve los pedidos a los clientes correctos
5. **Gestión**: Administra tiempo, dinero y eficiencia
6. **Progresión**: Alcanza objetivos para desbloquear nuevos niveles

### Mecánicas Avanzadas
- **Sistema de tiempo real**: Cada día tiene duración limitada
- **Música dinámica**: Cambia según la hora del día
- **Satisfacción del cliente**: Afecta las propinas y reputación
- **Gestión de inventario**: Control de ingredientes y suministros

## 🐛 Solución de Problemas

### Problemas Comunes
- **El juego no inicia**: Verifica que tengas Godot 4.4 o superior
- **Assets no cargan**: Asegúrate de que todos los archivos estén en las carpetas correctas
- **Rendimiento lento**: Ajusta la calidad gráfica en la configuración

## 🤝 Contribuir

Este es un proyecto estudiantil. Las contribuciones son bienvenidas:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/NuevaCaracteristica`)
3. Commit tus cambios (`git commit -m 'Añadir nueva característica'`)
4. Push a la rama (`git push origin feature/NuevaCaracteristica`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto es desarrollado con fines educativos como parte del curso de Desarrollo de Videojuegos.

## 👥 Desarrolladores

**Proyecto estudiantil - Universidad**
- Período: Mayo - Septiembre 2025
- Curso: Desarrollo de Videojuegos

---

## 📸 Screenshots

*[Agregar capturas de pantalla del juego aquí]*

## 🔮 Próximas Características

- [ ] Sistema de mejoras para el restaurante
- [ ] Más tipos de comida y recetas
- [ ] Modo multijugador cooperativo
- [ ] Sistema de logros
- [ ] Personalización del restaurante
- [ ] Eventos especiales y desafíos

---

**¡Gracias por jugar!** 🎮✨
