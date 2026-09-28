<template>
    <Transition name="fade">
        <div class="app" v-if="visible"
            :class="{ 'cursor-grabbing': draggedItem != null }"
            @mousemove="handleDragMove"
            @mouseup="endDrag"
        >
            <div class="backdrop"></div>

            <div class="panel"
                @mousedown="handleMouseDown"
                @mouseup="handleMouseUp"
                @mousemove="handleMouseMove"
            >
                <div
                    v-for="(slot, type) in slotPositions"
                    :key="type"
                    class="slot"
                    :class="{
                        filled: currentAttachments[type],
                        target: targetSlot === type,
                        hovered: hoveredSlot === type,
                        dimmed: draggedItem && targetSlot !== type,
                        source: draggedFromSlot === type
                    }"
                    :style="{ left: slot.x + 'px', top: slot.y + 'px' }"
                    @mousedown.stop="(e) => startDrag(e, currentAttachments[type], type)"
                >
                    <div class="slot-box">
                        <img
                            v-if="currentAttachments[type] && draggedFromSlot !== type"
                            :src="currentAttachments[type].image"
                        />
                        <span v-else class="slot-plus">+</span>
                    </div>
                    <span class="slot-label">{{ typeLabel(type) }}</span>
                </div>

                <div
                    v-if="draggedItem"
                    class="ghost"
                    :style="{ left: mouseX + 'px', top: mouseY + 'px' }"
                >
                    <img :src="draggedItem.image" />
                </div>
            </div>

            <aside class="sidebar">
                <header class="sidebar-header">
                    <div>
                        <span class="eyebrow">Weapon</span>
                        <h1>Components</h1>
                    </div>
                    <button class="close" @click="close" title="Close (ESC)">&times;</button>
                </header>

                <div class="sidebar-body">
                    <p v-if="components.length === 0" class="empty">
                        No compatible components in your inventory
                    </p>

                    <section v-for="group in groupedComponents" :key="group.type" class="group">
                        <h2>
                            {{ typeLabel(group.type) }}
                            <span>{{ group.items.length }}</span>
                        </h2>
                        <div class="grid">
                            <div
                                v-for="item in group.items"
                                :key="item.name"
                                class="card"
                                :class="{ dragging: draggedItem?.name === item.name && !draggedFromSlot }"
                                @mousedown="(e) => startDrag(e, item, null)"
                            >
                                <div class="card-image">
                                    <img :src="item.image" />
                                </div>
                                <span class="card-label">{{ item.label }}</span>
                            </div>
                        </div>
                    </section>
                </div>
            </aside>

            <Transition name="fade">
                <div v-if="draggedFromSlot && !hoveredSlot" class="detach-hint">
                    Release to detach
                </div>
            </Transition>

            <footer class="hints">
                <span><kbd>LMB</kbd> Drag to rotate</span>
                <span><kbd>Drag</kbd> Component onto slot</span>
                <span><kbd>ESC</kbd> Close</span>
            </footer>
        </div>
    </Transition>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref } from 'vue'
import type { ComponentItem, SlotComponent } from './types/component';
import api from './api/axios';

// Distance in px from slot center that counts as dropping on it
const DROP_RADIUS = 40

const TYPE_LABELS: Record<string, string> = {
    flashlight: 'Flashlight',
    sight: 'Sight',
    muzzle: 'Muzzle',
    magazine: 'Magazine',
    grip: 'Grip',
    skin: 'Finish'
}

const visible = ref(false)
const slotPositions = ref<Record<string, { x: number; y: number }>>({})
const components = ref<ComponentItem[]>([])
const currentAttachments = ref<Record<string, ComponentItem>>({})
const draggedItem = ref<ComponentItem | null>(null)
const draggedFromSlot = ref<string | null>(null)
const isRotatingEnabled = ref(true)

// Rotation drag state
const isDragging = ref(false)
let lastX = 0
let lastY = 0
let pendingYaw = 0
let pendingPitch = 0
let rotateFrame = 0

const mouseX = ref(0)
const mouseY = ref(0)
const hoveredSlot = ref<string | null>(null)

// Slot the dragged component belongs in
const targetSlot = computed(() => draggedItem.value?.type ?? null)

const groupedComponents = computed(() => {
    const groups: Record<string, ComponentItem[]> = {}

    for (const item of components.value) {
        (groups[item.type] ??= []).push(item)
    }

    return Object.entries(groups).map(([type, items]) => ({ type, items }))
})

const typeLabel = (type: string) =>
    TYPE_LABELS[type] ?? type.charAt(0).toUpperCase() + type.slice(1)

onMounted(() => {
    window.addEventListener('message', (e) => {
        const { action } = e.data

        if (action === 'open') {
            const { availableComponents, attachedComponents } = e.data
            visible.value = true
            components.value = availableComponents

            updateAttachedComponents(attachedComponents)
        } else if (action === 'updateSlot') {
            const { x, y, slot } = e.data;

            const px = x * window.innerWidth
            const py = y * window.innerHeight
            slotPositions.value[slot] = { x: px, y: py }
        } else if (action === 'hideSlot') {
            // Slot is off screen or its bone is missing
            delete slotPositions.value[e.data.slot]
        } else if (action === 'close') {
            slotPositions.value = {}
            components.value = []
            currentAttachments.value = {}
            visible.value = false
        }
    })

    window.addEventListener('keyup', (e) => {
        if (e.key == 'Escape' && visible.value) {
            close();
        }
    })
})

const updateAttachedComponents = (attachedComponents: SlotComponent[]) => {
    currentAttachments.value = {}

    for (const slotComponent of attachedComponents) {
        currentAttachments.value[slotComponent.slotType] = slotComponent.component
    }
}

function close() {
    api.post('close', {})
    visible.value = false
}

const handleMouseDown = (e: MouseEvent) => {
    if (!isRotatingEnabled.value) return;

    isDragging.value = true
    lastX = e.clientX
    lastY = e.clientY
}

const handleMouseUp = () => {
    isDragging.value = false
}

const handleMouseMove = (e: MouseEvent) => {
    if (!isDragging.value || !isRotatingEnabled.value) return

    const deltaX = e.clientX - lastX
    const deltaY = e.clientY - lastY
    lastX = e.clientX
    lastY = e.clientY

    pendingYaw += deltaX * 0.5
    pendingPitch += -deltaY * 0.5

    // Mouse moves fire far more often than frames, send at most one rotation per frame
    if (!rotateFrame) {
        rotateFrame = requestAnimationFrame(sendRotation)
    }
}

const sendRotation = () => {
    rotateFrame = 0

    api.post('rotatePreviewDelta', {
        deltaYaw: pendingYaw,
        deltaPitch: pendingPitch
    })

    pendingYaw = 0
    pendingPitch = 0
}

const startDrag = (e: MouseEvent, item: ComponentItem | undefined, slotName: string | null) => {
    e.preventDefault()

    if (!item) return

    isRotatingEnabled.value = false;

    draggedItem.value = item
    draggedFromSlot.value = slotName

    mouseX.value = e.clientX
    mouseY.value = e.clientY
    hoveredSlot.value = findSlotAt(e.clientX, e.clientY)
}

const findSlotAt = (x: number, y: number) => {
    for (const [name, pos] of Object.entries(slotPositions.value)) {
        if (Math.hypot(pos.x - x, pos.y - y) < DROP_RADIUS) {
            return name
        }
    }

    return null
}

const handleDragMove = (e: MouseEvent) => {
    if (!draggedItem.value) return
    mouseX.value = e.clientX
    mouseY.value = e.clientY

    hoveredSlot.value = findSlotAt(e.clientX, e.clientY)
}

const endDrag = async () => {
    if (!draggedItem.value) return

    const droppedOnSlot = findSlotAt(mouseX.value, mouseY.value)

    try {
        let response

        if (droppedOnSlot) {
            if (droppedOnSlot !== draggedFromSlot.value) {
                response = await api.post('attach', {
                    slot: droppedOnSlot,
                    component: draggedItem.value
                })
            }
        } else if (draggedFromSlot.value) {
            response = await api.post('remove', {
                slot: draggedFromSlot.value
            })
        }

        if (response?.data?.attachedComponents) {
            components.value = response.data.availableComponents
            updateAttachedComponents(response.data.attachedComponents)
        }
    } finally {
        isRotatingEnabled.value = true
        draggedItem.value = null
        hoveredSlot.value = null
        draggedFromSlot.value = null
    }
}

</script>

<style scoped>
.app {
    width: 100vw;
    height: 100vh;
    position: relative;
    overflow: hidden;
}

.cursor-grabbing,
.cursor-grabbing * {
    cursor: grabbing !important;
}

/* Darkens the game while keeping the weapon in the center readable */
.backdrop {
    position: absolute;
    inset: 0;
    pointer-events: none;
    background:
        radial-gradient(ellipse 55% 60% at 55% 50%, rgba(0, 0, 0, 0.15) 0%, rgba(0, 0, 0, 0.5) 70%, rgba(0, 0, 0, 0.92) 100%);
}

.panel {
    position: absolute;
    inset: 0;
    cursor: grab;
}

/* Sidebar */

.sidebar {
    position: absolute;
    top: 24px;
    left: 24px;
    bottom: 24px;
    width: 340px;
    display: flex;
    flex-direction: column;
    background: var(--bg-panel);
    border: 1px solid var(--border);
    border-radius: 14px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    overflow: hidden;
}

.sidebar-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    padding: 22px 22px 18px;
    border-bottom: 1px solid var(--border);
}

.eyebrow {
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--accent);
}

h1 {
    margin: 4px 0 0;
    font-size: 22px;
    font-weight: 700;
    letter-spacing: -0.01em;
}

.close {
    width: 32px;
    height: 32px;
    display: grid;
    place-items: center;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: transparent;
    color: var(--text-muted);
    font-size: 20px;
    line-height: 1;
    cursor: pointer;
    transition: background 0.15s, color 0.15s, border-color 0.15s;
}

.close:hover {
    background: rgba(239, 91, 91, 0.12);
    border-color: rgba(239, 91, 91, 0.4);
    color: var(--danger);
}

.sidebar-body {
    flex: 1;
    overflow-y: auto;
    padding: 16px 22px 22px;
}

.sidebar-body::-webkit-scrollbar {
    width: 6px;
}

.sidebar-body::-webkit-scrollbar-thumb {
    background: var(--border-strong);
    border-radius: 3px;
}

.empty {
    margin: 40px 0;
    text-align: center;
    font-size: 13px;
    color: var(--text-faint);
}

.group + .group {
    margin-top: 20px;
}

.group h2 {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 0 0 10px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--text-muted);
}

.group h2 span {
    padding: 1px 6px;
    border-radius: 4px;
    background: var(--bg-card-hover);
    color: var(--text-faint);
    letter-spacing: 0;
}

.grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 8px;
}

.card {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 10px;
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    cursor: grab;
    transition: background 0.15s, border-color 0.15s, transform 0.15s;
}

.card:hover {
    background: var(--bg-card-hover);
    border-color: var(--accent-glow);
    transform: translateY(-1px);
}

.card.dragging {
    opacity: 0.4;
}

.card-image {
    height: 56px;
    display: grid;
    place-items: center;
}

.card-image img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
}

.card-label {
    font-size: 12px;
    font-weight: 500;
    line-height: 1.3;
    color: var(--text);
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

/* Slots */

.slot {
    position: absolute;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    transform: translate(-50%, -28px);
    transition: opacity 0.2s;
    cursor: pointer;
}

.slot-box {
    width: 56px;
    height: 56px;
    display: grid;
    place-items: center;
    border: 1.5px dashed var(--border-strong);
    border-radius: 12px;
    background: rgba(12, 13, 16, 0.6);
    transition: transform 0.15s, border-color 0.15s, background 0.15s, box-shadow 0.15s;
}

.slot-box img {
    width: 44px;
    height: 44px;
    object-fit: contain;
}

.slot-plus {
    font-size: 20px;
    font-weight: 300;
    color: var(--text-faint);
}

.slot-label {
    padding: 2px 8px;
    border-radius: 999px;
    background: rgba(12, 13, 16, 0.8);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--text-muted);
    white-space: nowrap;
}

.slot.filled .slot-box {
    border-style: solid;
    border-color: var(--border-strong);
    background: rgba(12, 13, 16, 0.85);
}

.slot:hover .slot-box {
    border-color: var(--text-muted);
}

.slot.dimmed {
    opacity: 0.3;
}

.slot.target .slot-box {
    border-style: solid;
    border-color: var(--accent);
    background: var(--accent-soft);
    animation: pulse 1.2s ease-in-out infinite;
}

.slot.target .slot-label {
    color: var(--accent);
}

.slot.target .slot-plus {
    color: var(--accent);
}

.slot.target.hovered .slot-box {
    transform: scale(1.12);
    background: rgba(240, 180, 60, 0.3);
    box-shadow: 0 0 0 4px var(--accent-soft), 0 0 28px var(--accent-glow);
    animation: none;
}

/* Hovering a slot the component doesn't fit */
.slot.dimmed.hovered {
    opacity: 0.6;
}

.slot.dimmed.hovered .slot-box {
    border-color: var(--danger);
}

@keyframes pulse {
    0%, 100% { box-shadow: 0 0 0 0 var(--accent-glow); }
    50% { box-shadow: 0 0 0 8px rgba(240, 180, 60, 0); }
}

.ghost {
    position: fixed;
    width: 64px;
    height: 64px;
    display: grid;
    place-items: center;
    pointer-events: none;
    transform: translate(-50%, -50%) rotate(-4deg);
    background: rgba(12, 13, 16, 0.9);
    border: 1.5px solid var(--accent);
    border-radius: 12px;
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.5);
    z-index: 1000;
}

.ghost img {
    width: 48px;
    height: 48px;
    object-fit: contain;
}

/* Hints */

.detach-hint {
    position: absolute;
    top: 32px;
    left: 50%;
    transform: translateX(-50%);
    padding: 8px 16px;
    border-radius: 999px;
    background: rgba(239, 91, 91, 0.15);
    border: 1px solid rgba(239, 91, 91, 0.45);
    color: var(--danger);
    font-size: 12px;
    font-weight: 600;
    pointer-events: none;
}

.hints {
    position: absolute;
    right: 24px;
    bottom: 24px;
    display: flex;
    gap: 18px;
    padding: 10px 16px;
    background: var(--bg-panel);
    border: 1px solid var(--border);
    border-radius: 10px;
    font-size: 12px;
    color: var(--text-muted);
    pointer-events: none;
}

kbd {
    margin-right: 6px;
    padding: 2px 6px;
    border: 1px solid var(--border-strong);
    border-bottom-width: 2px;
    border-radius: 4px;
    font-family: inherit;
    font-size: 10px;
    font-weight: 600;
    color: var(--text);
}

.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}
</style>
