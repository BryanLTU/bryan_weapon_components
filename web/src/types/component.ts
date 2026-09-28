export interface ComponentItem {
    name: string;
    label: string;
    image: string;
    type: string;
    component: number;
}

export interface SlotComponent {
    component: ComponentItem,
    slotType: string
}
