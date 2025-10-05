<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="fetch-tileset" tilewidth="16" tileheight="16" tilecount="400" columns="20">
 <editorsettings>
  <export target="fetch-tileset.lua" format="lua"/>
 </editorsettings>
 <image source="../tiles/fetch-tileset.png" width="320" height="320"/>
 <tile id="0">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="is_water" type="bool" value="true"/>
  </properties>
 </tile>
 <tile id="20" type="blue_duck"/>
 <tile id="21" type="pink_duck"/>
 <tile id="22" type="wizard_duck::no_cap"/>
 <tile id="23" type="wizard_duck::with_hat"/>
 <tile id="24" type="money_bags_duck"/>
 <tile id="25" type="courier_duck"/>
 <tile id="26" type="gift_duck::no_gift"/>
 <tile id="27" type="gift_duck::with_gift"/>
 <tile id="28" type="shop_keep_duck"/>
 <tile id="29" type="chef_duck"/>
 <tile id="30" type="king_duck"/>
 <tile id="31" type="doomsday_prepper_duck::no_tp"/>
 <tile id="32" type="doomsday_prepper_duck::with_tp"/>
 <tile id="33" type="sock_duck::no_sock"/>
 <tile id="34" type="sock_duck::with_sock1"/>
 <tile id="35" type="sock_duck::with_sock2"/>
 <tile id="40" type="farmer_duck"/>
 <tile id="41" type="cartographer_duck"/>
 <tile id="42" type="pirate_duck"/>
 <tile id="43" type="lifeguard_duck"/>
 <tile id="44" type="cyan_duck"/>
 <tile id="45" type="woodcutter_duck"/>
 <tile id="46" type="glitch_duck_1"/>
 <tile id="47" type="glitch_duck_2"/>
 <tile id="48" type="grey_duck"/>
 <tile id="49" type="plumber_duck"/>
 <tile id="50" type="cat_lady_duck::no_cat"/>
 <tile id="51" type="cat_lady_duck::with_cat"/>
 <tile id="60" type="right_goose"/>
 <tile id="61" type="left_goose"/>
 <tile id="62" type="white_goose"/>
 <tile id="63" type="canada_goose"/>
 <tile id="100" type="ground::grass"/>
 <tile id="102" type="ground::dirt"/>
 <tile id="104" type="ground::sand"/>
 <tile id="106" type="ground::path"/>
 <tile id="108" type="water">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="-0.1"/>
   <property name="is_water" type="bool" value="true"/>
  </properties>
 </tile>
 <tile id="110" type="ground::clay"/>
 <tile id="112" type="ground::carpet"/>
 <tile id="114" type="ground::stone"/>
 <tile id="128" type="picket::cap_left"/>
 <tile id="130" type="picket::cap_right"/>
 <tile id="134" type="gravel::bl_corner2"/>
 <tile id="140" type="wall">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="141" type="wall::vines">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="142" type="wall::broken">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="144" type="door"/>
 <tile id="148" type="picket::left_side"/>
 <tile id="150" type="picket::right_side"/>
 <tile id="152" type="gravel::br_corner"/>
 <tile id="153" type="gravel::cross"/>
 <tile id="154" type="gravel::ew2"/>
 <tile id="155" type="gravel::tr_corner"/>
 <tile id="160" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="161" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="162" type="rock"/>
 <tile id="163" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="164" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.7"/>
  </properties>
 </tile>
 <tile id="165" type="rock">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="166" type="rock::ice"/>
 <tile id="168" type="picket::bl_corner"/>
 <tile id="169" type="picket::front"/>
 <tile id="170" type="picket::br_corner"/>
 <tile id="173" type="gravel::ns"/>
 <tile id="175" type="gravel::ns_2"/>
 <tile id="180" type="tree">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="1"/>
  </properties>
 </tile>
 <tile id="181" type="decor::mushroom"/>
 <tile id="182" type="decor::grass"/>
 <tile id="183" type="bush">
  <properties>
   <property name="collides" type="bool" value="true"/>
   <property name="height" type="float" value="0.5"/>
  </properties>
 </tile>
 <tile id="193" type="gravel::bl_corner2"/>
 <tile id="194" type="gravel::ew"/>
 <tile id="195" type="gravel::br_corner"/>
 <tile id="200" type="throne"/>
 <tile id="201" type="decor::books"/>
 <tile id="240" type="item::cat"/>
 <tile id="241" type="item::book"/>
 <tile id="242" type="item::no_icon"/>
 <tile id="243" type="item::floaties"/>
 <tile id="244" type="item::labubu"/>
 <tile id="245" type="item::package"/>
 <tile id="246" type="item::duck"/>
 <tile id="247" type="item::shoe"/>
 <tile id="248" type="item::planks"/>
 <tile id="250" type="item::wizard_hat"/>
</tileset>
