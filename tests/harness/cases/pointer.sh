# Synthetic pointer lands where it was told to, including the very first warp.

case_body() {
    warp 640 400
    assert_eq "640 400" "$(eval_value 'let [x,y]=global.get_pointer(); `${x} ${y}`')" \
        "first warp of the run lands exactly"

    warp 100 200
    assert_eq "100 200" "$(eval_value 'let [x,y]=global.get_pointer(); `${x} ${y}`')" \
        "later warp lands exactly"

    move_pointer 50 -25
    assert_eq "150 175" "$(eval_value 'let [x,y]=global.get_pointer(); `${x} ${y}`')" \
        "relative motion accumulates"
}
