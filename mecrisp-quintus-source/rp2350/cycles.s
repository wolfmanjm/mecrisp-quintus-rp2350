#
#    Mecrisp-Quintus - A native code Forth implementation for RISC-V
#    Copyright (C) 2018  Matthias Koch
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Cycle counters, with special CSRs for machine mode counters.

.ifndef RV64

# -----------------------------------------------------------------------------
  Definition Flag_visible, "cycles64" # Uptime in cycles, 64 bits
cycles64:
# -----------------------------------------------------------------------------
  pushdatos

1:csrrs x15, 0x0B80, zero # rdcycleh x15
  csrrs x8,  0x0B00, zero # rdcycle  x8
  csrrs x14, 0x0B80, zero # rdcycleh x14
  bne x15, x14, 1b

  pushda x15
  ret

.endif

# -----------------------------------------------------------------------------
  Definition Flag_visible, "cycles" # Uptime in cycles, 32 bits
cycles:
# -----------------------------------------------------------------------------
  pushdatos
  csrrs x8, 0x0B00, zero # rdcycle x8
  ret
