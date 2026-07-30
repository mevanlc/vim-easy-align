# a vim-easy-align fork

This is a fork of [vim-easy-align](https://github.com/junegunn/vim-easy-align),
a simple alignment plugin for Vim. See the upstream repository for general
usage documentation. The bundled `:help easy-align` includes the additions in
this fork.

## about this fork

This fork preserves the upstream interface and adds:

- an optional, unfocused help split for interactive alignment;
- N-th delimiter `0` for block-edge and leading-whitespace alignment;
- linewise space-between and equal-cell justification; and
- rightward-only extension to an existing delimiter column.

Commands, mappings, and defaults otherwise follow upstream vim-easy-align.

### interactive help split

Interactive EasyAlign can show a syntax-highlighted reference below or to the
right of the target window:

```vim
" Disabled (default)
let g:easy_align_auto_open_help_in_unfocused_split = ''

" Open below or to the right of the target
let g:easy_align_auto_open_help_in_unfocused_split = 'horizontal'
let g:easy_align_auto_open_help_in_unfocused_split = 'vertical'
```

The target window keeps focus, so the split does not capture input or change the
`ga`, `gA`, `:EasyAlign`, or `:LiveEasyAlign` grammar. The help follows the
current interactive state, updates its finish instructions when `<CTRL-P>`
toggles live preview, and closes when alignment finishes or is cancelled.

The feature requires Vim window-ID support. Any setting other than `''`,
`'horizontal'`, or `'vertical'` is rejected.

### extending to an existing delimiter column

The `extend` option prevents alignment from pulling delimiters left of the
rightmost original delimiter start. For example, select these lines and use
`ga<CTRL-E>#`:

```bash
--check-fs-case-sensitivity   # default
--no-check-fs-case-sensitivity      # do not check filesystem case sensitivity
```

The farther comment column is retained:

```bash
--check-fs-case-sensitivity         # default
--no-check-fs-case-sensitivity      # do not check filesystem case sensitivity
```

`<CTRL-E>` toggles extension in interactive mode. The command forms are:

```vim
:'<,'>EasyAlign #e1
:'<,'>EasyAlign # { 'extend': 1 }
```

Extension defaults to `0`, measures display columns correctly for tabs and wide
characters, and considers only delimiters that remain after filtering and
syntax-group checks. It cannot be combined with `justify`.

### justifying rows to the widest line

The `justify` option splits participating lines into cells at every matched
delimiter and expands shorter lines to the display width of the widest one.
`between` distributes space across the gaps:

```vim
:'<,'>EasyAlign */]/jb
```

```text
[iCopy]                [iCut]               [iPaste]
[iSendToBack][iSendBack][iSendForward][iSendToFront]
[Foo]                                          [Bar]
```

`cells` balances the cell widths. The existing `align` option positions content
within each cell; this example uses left alignment:

```vim
:'<,'>EasyAlign */]/jcal
```

```text
[iCopy          ][iCut           ][iPaste          ]
[iSendToBack][iSendBack][iSendForward][iSendToFront]
[Foo                     ][Bar                     ]
```

In interactive mode, `<CTRL-J>` cycles from normal column alignment to
space-between justification and then equal-cell justification. Long cells keep
their minimum width and are never truncated. Justification is linewise;
blockwise visual selections are not supported.

### N-th delimiter 0

In blockwise visual mode, occurrence `0` selects the delimiter crossing the
block's left edge on each line. The complete delimiter run participates even
when part of it lies outside the block. For a block drawn over whitespace
between two columns, use:

```vim
ga0<Space>
```

Lines without a delimiter at the block edge remain unchanged, and margin
controls such as `<CTRL-R>` can move the result farther right.

When the block starts in column 1, `0<Space>` removes leading indentation. The
same leading-whitespace operation is available in normal or linewise visual
ranges:

```vim
1Gga}0<Space>
1GV}ga0<Space>
:execute '%EasyAlign 0\ '
```

Outside blockwise mode, occurrence `0` is supported only with the whitespace
delimiter; lines already beginning in column 1 remain unchanged.

## installation

Use your preferred Vim plugin manager with this fork. For example, with
[vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'mevanlc/vim-easy-align'

xmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)
```

This is a Vimscript plugin and has no build step.

## license

vim-easy-align is released under the MIT License. Copyright (c) 2014 Junegunn
Choi.
