/// ND 中性密度滤镜枚举。`stops` 表示需要补偿的曝光档位。
enum NdFilter {
  none(0, '0'),
  nd2(1, 'ND2'),
  nd4(2, 'ND4'),
  nd8(3, 'ND8'),
  nd16(4, 'ND16'),
  nd32(5, 'ND32'),
  nd64(6, 'ND64'),
  nd128(7, 'ND128'),
  nd256(8, 'ND256'),
  nd512(9, 'ND512'),
  nd1024(10, 'ND1024');

  const NdFilter(this.stops, this.display);

  final double stops;
  final String display;
}
