ENTRY(_start)

SECTIONS
{
	. = 0;

	.text : ALIGN(16)
	{
		*(.text .text.*)
		*(.rodata .rodata.*)
	}

	. = ALIGN(16);

	.payload :
	{
		KEEP(*(.payload))
	}

	/DISCARD/ :
	{
		*(.comment*)
		*(.note*)
		*(.eh_frame*)
	}
}
