export interface ComponentItem {
    name: string;
    label: string;
    image: string;
}

export interface SlotComponent {
    component: ComponentItem,
    slotType: string
}