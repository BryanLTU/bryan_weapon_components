<template>
    <div class="app" v-if="visible"
        :class="{ 'cursor-grabbing': draggedItem != null }"
        @mousemove="handleDragMove"
        @mouseup="endDrag"
    >
        <div class="sidebar">
            <div class="toolbar">
                <button @click="close">Close</button>
            </div>
            <div
                class="component"
                v-for="(item, index) in components"
                :key="index"
                @mousedown="(e) => startDrag(e, item, null)"
            >
                <img :src="item.image" />
                <span>{{ item.label }}</span>
            </div>
        </div>
        <div class="panel"
            @mousedown="handleMouseDown"
            @mouseup="handleMouseUp"
            @mousemove="handleMouseMove"
        >
            <div
                v-for="(slot, index) in slotPositions"
                :key="index"
                class="slot"
                :style="{ left: slot.x + 'px', top: slot.y + 'px' }"
                @mousedown="(e) => startDrag(e, currentAttachments[index], index)"
            >
                <img
                    v-if="currentAttachments[index]"
                    :src="currentAttachments[index].image"
                    class="attachment"
                />
                <!-- <span v-else style="color: white;">{{ index }}</span> -->
            </div>
            <div
                v-if="draggedItem"
                class="ghost"
                :style="{ left: mouseX + 'px', top: mouseY + 'px' }"
            >
                <img :src="draggedItem.image" />
            </div>
        </div>
    </div>
</template>

<script lang="ts" setup>
import { onMounted, ref } from 'vue'
import type { ComponentItem, SlotComponent } from './types/component';
import api from './api/axios';

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

const mouseX = ref(0)
const mouseY = ref(0)
const hoveredSlot = ref<string | null>(null)

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
        } else if (action === 'close') {
            slotPositions.value = {}
            components.value = []
            currentAttachments.value = {}
            visible.value = false
        }
    })
    
    window.addEventListener('keyup', (e) => {
        if (e.key == 'Escape') {
            close();
        }
    })
})

const updateAttachedComponents = (attachedComponents: SlotComponent[]) => {
    currentAttachments.value = {}

    for (var slotComponent of attachedComponents) {
        currentAttachments.value[slotComponent.slotType] = slotComponent.component
    }
}

function close() {
    fetch(`https://bryan_weapon_components/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{}',
    })
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
    
    fetch(`https://bryan_weapon_components/rotatePreviewDelta`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            deltaYaw: deltaX * 0.5,
            deltaPitch: -deltaY * 0.5
        })
    })
}

const startDrag = (e: MouseEvent, item: ComponentItem, slotName: string | null) => {
    e.preventDefault()

    if (!item) return

    isRotatingEnabled.value = false;

    draggedItem.value = item
    draggedFromSlot.value = slotName
    
    mouseX.value = e.clientX
    mouseY.value = e.clientY
}

const handleDragMove = (e: MouseEvent) => {
    if (!draggedItem.value) return
    mouseX.value = e.clientX
    mouseY.value = e.clientY
    
    // Slot hit detection
    // hoveredSlot.value = null
    // for (const [name, pos] of Object.entries(slotPositions.value)) {
    //     const dist = Math.hypot(pos.x - mouseX.value, pos.y - mouseY.value)
    //     if (dist < 30) {
    //         hoveredSlot.value = name
    //         break
    //     }
    // }
}

const endDrag = async () => {
    if (!draggedItem.value) return

    let droppedOnSlot: string | null = null
    for (const [name, pos] of Object.entries(slotPositions.value)) {
        const dist = Math.hypot(pos.x - mouseX.value, pos.y - mouseY.value)

        if (dist < 32) {
            droppedOnSlot = name
            break
        }
    }
    
    if (droppedOnSlot) {
        const response = await api.post('attach', {
            slot: droppedOnSlot,
            component: draggedItem.value
        })
        
        if (response.data) {
            components.value = response.data.availableComponents
            updateAttachedComponents(response.data.attachedComponents)
        }
    }
    else if (draggedFromSlot.value) {
        const response = await api.post('remove', {
            slot: draggedFromSlot.value
        })

        if (response.data) {
            components.value = response.data.availableComponents
            updateAttachedComponents(response.data.attachedComponents)
        }
    }
    
    isRotatingEnabled.value = true
    draggedItem.value = null
    hoveredSlot.value = null
    draggedFromSlot.value = null
}

</script>

<style scoped>
.app {
  width: 100vw;
  height: 100vh;
  position: relative;
  overflow: hidden;
  /* display: flex; */
}

.toolbar {
    top: 10px;
    left: 10px;
}

.sidebar {
    position: absolute;
    width: 15%;
    height: 100%;
    background: rgba(10, 10, 10, 0.7);
    overflow-y: auto;
    padding: 10px;
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.panel {
    /* width: 85%; */
    width: 100%;
    height: 100%;
    overflow: hidden;
}

.component {
    background: #222;
    border: 1px solid #444;
    padding: 6px;
    cursor: grab;
    display: flex;
    flex-direction: column;
    align-items: center;
    pointer-events: all;
    color: white;
}

.component img {
    max-width: 100%;
    height: 40px;
    margin-bottom: 4px;
}

.slot {
    position: absolute;
    width: 48px;
    height: 48px;
    background: rgba(255, 255, 255, 0.1);
    border: 2px solid white;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: all;
    transform: translate(-50%, -50%);
}

.attachment {
    width: 40px;
    height: 40px;
}

.ghost {
    position: fixed;
    pointer-events: none;
    width: 48px;
    height: 48px;
    transform: translate(-50%, -50%);
    z-index: 1000;
}

.ghost img {
    width: 100%;
    height: 100%;
}

.slot.hovered {
    border-color: lime;
    background-color: rgba(0, 255, 0, 0.15);
}

.cursor-grabbing {
    cursor: grabbing;
}
</style>
