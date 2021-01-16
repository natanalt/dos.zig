# Resize the program's memory block and update its segments' base addresses.
# This function must be entered with a far call.
#
# Inputs:
# BX:CX = new size of block
# SI:DI = memory block handle
#
# Outputs:
# AX    = error code
# BX:CX = new base address
# SI:DI = new memory block handle

.global resize_self;
resize_self:

# Resize memory block. Inputs are set by caller.
mov $0x503, %ax
int $0x31
jc .Labort

# Move returned linear address for next interrupt.
mov %cx, %dx
mov %bx, %cx

# Update base address of program's data segment.
mov $0x7, %ax
mov %ds, %bx
int $0x31
jc .Labort

# Update base address of program's code segment.
# Saved CS can be found on stack beyond saved EIP.
movw 4(%esp), %bx
int $0x31
jc .Labort

# Clear error code register.
xor %ax, %ax

# Move linear address back to BX:CX for caller.
mov %cx, %bx
mov %dx, %cx

.Labort:
lret

.global resize_self_end;
resize_self_end:
