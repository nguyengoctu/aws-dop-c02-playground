<?php
// Giả lập độ trễ cao để trigger CloudWatch Alarm (Threshold > 0.5s)
sleep(2);
echo "<h1>v2.0 - Slow Response!</h1>";
echo "<p>This page took 2 seconds to load. CloudWatch Alarm should trigger and Rollback deployment.</p>";
?>
