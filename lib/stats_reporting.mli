open Core.Std

type field with sexp, bin_io

val init : msg:string -> unit
val create_field    : desc:string -> type_desc:string -> name:string -> field
val add_datum       : field -> int -> unit
val add_datum_float : field -> float -> unit
val resize_if_required : unit -> unit


type type_desc = string with sexp, bin_io
type name = string with sexp, bin_io
type t =
| New_field   of int * string * type_desc * name
| Int_datum   of int * int   * Time_stamp_counter.Cycles.t
| Float_datum of int * float * Time_stamp_counter.Cycles.t
with sexp, bin_io

val read_msg_and_snapshot : file:string -> string * Time_stamp_counter.Cycles.snapshot
val fold : file:string -> init:'a -> f:('a -> t -> 'a) -> 'a




