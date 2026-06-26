using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics.Eventing.Reader;
using System.Drawing;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Media;



namespace Biyoproje_arayuz
{
    public partial class Form1 : Form
    {
        string distance;
        string horizontal;
        string vertical;
        string delay;
        string repeat;
        string mot_speed;
        string camdelay;
         
        int i = 0;
        int stop_but = 0;

        int x = 0;
        int y = 0;
        
        public Form1()
        {
            InitializeComponent();
            upbutton.Enabled = false;
            downbutton.Enabled = false;
            rightbutton.Enabled = false;
            leftbutton.Enabled = false;
            manueldist.Enabled = false;
            button1.Enabled = false;
            button2.Enabled = false;
            timer1.Interval = 250; // 0.25 saniye
            timer1.Tick += Timer1_Tick; // Timer'ın Tick olayını bağla
            timer1.Start(); // Timer'ı başlat
            UpdateComPorts(); // Başlangıçta portları güncell

        }

        private void Timer1_Tick(object sender, EventArgs e)
        {
            UpdateComPorts(); // Her tick'te portları güncelle
        }
        private void UpdateComPorts()
        {
            // Mevcut portları al
            string[] ports = SerialPort.GetPortNames();

            // ComboBox'taki mevcut seçili öğeyi hatırla
            string selectedPort = comboBox1.SelectedItem?.ToString();

            // ComboBox'ı temizle
            comboBox1.Items.Clear();

            // Yeni portları ekle
            comboBox1.Items.AddRange(ports);

            // Eğer önceden seçili bir port varsa ve hala mevcutsa, onu seçili yap
            if (!string.IsNullOrEmpty(selectedPort) && comboBox1.Items.Contains(selectedPort))
            {
                comboBox1.SelectedItem = selectedPort;

                // Port açıksa kapat
                if (SerialPort.IsOpen)
                {
                    SerialPort.Close();
                }

                SerialPort.PortName = comboBox1.SelectedItem.ToString(); //comboBox1'de seçili olan portu port ismine ata
                SerialPort.Open(); //Seri portu aç
            }
            /*else if (comboBox1.Items.Count > 0)
            {
                comboBox1.SelectedIndex = 0; // Yoksa ilk portu seç
            }*/
        }
        private void oto_Click(object sender, EventArgs e)
        {

                // Önce port seçimini kontrol et
            if (string.IsNullOrEmpty(comboBox1.Text))
            {
                // Eğer bir port seçilmemişse hata mesajı göster
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir seri port seçin!", "Hata");
                
            }
            else if (string.IsNullOrEmpty(disttext.Text) || string.IsNullOrEmpty(horizontaltext.Text) ||
                string.IsNullOrEmpty(verticaltext.Text) || string.IsNullOrEmpty(delaytext.Text) || 
                string.IsNullOrEmpty(repeatbox.Text) || string.IsNullOrEmpty(camdelaybox.Text) || string.IsNullOrEmpty(speedbox.Text))
            {
                // Eğer diğer giriş değerleri eksikse hata mesajı göster
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Bazı giriş değerleri eksik! Lütfen tüm alanları doldurun.", "Hata");
                
            }else if(Convert.ToInt32(speedbox.Text)>5000 || Convert.ToInt32(speedbox.Text) < 5)
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Motor Hızı 5-5000 arasında olmalıdır!", "Hata");
            }
            else
            {
                // Eğer her şey doğruysa işlemleri başlat
                upbutton.Enabled = false;
                downbutton.Enabled = false;

                rightbutton.Enabled = false;
                leftbutton.Enabled = false;
                manueldist.Enabled = false;
                button1.Enabled = true;
                button2.Enabled = true;


                label1.Text = "Otomotik";

                int intdist = Convert.ToInt32(disttext.Text);
                int inthor = Convert.ToInt32(horizontaltext.Text); //y ekseni
                int intver = Convert.ToInt32(verticaltext.Text); //x ekseni

                int x_dist = intdist * inthor;
                int y_dist = intdist * intver;

                if ((y + y_dist) > 20000)
                {
                    MessageBox.Show("Y Ekseni Hareketi Sınırlara Sığmamaktadır", "Hata");
                }
                else if ((x - x_dist) < -20000)
                {
                    MessageBox.Show("X Ekseni Hareketi Sınırlara Sığmamaktadır", "Hata");
                }
                else if ((y + y_dist) < 20000 & (x - x_dist) > -20000)
                {
                    distance = disttext.Text.ToString();       // Mesafe değeri
                    horizontal = horizontaltext.Text.ToString(); // Yatay pozisyon değeri
                    vertical = verticaltext.Text.ToString();   // Dikey pozisyon değeri
                    delay = delaytext.Text.ToString();         // Gecikme değeri
                    repeat = repeatbox.Text.ToString();
                    camdelay = camdelaybox.Text.ToString();
                    mot_speed = speedbox.Text.ToString();

                    // Seri port üzerinden verileri string olarak gönder
                    SerialPort.Write($"0,{distance},{horizontal},{vertical},{delay},{repeat},{mot_speed},{camdelay}");
                }

            }
            
        }

        private void manuel_Click(object sender, EventArgs e)
        {

            if (string.IsNullOrEmpty(comboBox1.Text))
            {
                SystemSounds.Exclamation.Play(); 
                MessageBox.Show("Lütfen bir seri port seçin!", "Hata");
            }
            else
            {
                label1.Text = "Manuel";
                SerialPort.Write($"1,0,0,0,0,0");
                upbutton.Enabled = true;
                downbutton.Enabled = true;
                rightbutton.Enabled = true;
                leftbutton.Enabled = true;
                manueldist.Enabled = true;
            }   
            
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            /*string[] ports = SerialPort.GetPortNames();  //Seri portları diziye ekleme
            foreach (string port in ports)
                comboBox1.Items.Add(port);               //Seri portları comboBox1'e ekleme*/
        }
        
        private void comboBox1_SelectedIndexChanged(object sender, EventArgs e)
        {
            //SerialPort.PortName = comboBox1.SelectedItem.ToString(); //comboBox1'de seçili olan portu port ismine ata
            //SerialPort.Open(); //Seri portu aç
        }



        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (SerialPort.IsOpen) SerialPort.Close();  //Eğer port açıksa kapat
        }


        private void upbutton_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(manueldist.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir mesafe belirleyiniz!", "Hata");
            }
            else 
            {
                int distint = Convert.ToInt32(manueldist.Text);
                x = x + distint;
                if(x > 20000)
                {
                    x = x - distint;
                    SystemSounds.Exclamation.Play();
                    MessageBox.Show("X Ekseni İçin Fazla Değer Girdiniz!", "Hata");
          
                }
                else
                {
                    distance = manueldist.Text.ToString();       // Mesafe değeri
                    SerialPort.Write($"1,{distance},8,0,0,0");
                }
                
            }
            
        }

        private void downbutton_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(manueldist.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir mesafe belirleyiniz!", "Hata");
                
            }
            else
            {
                int distint = Convert.ToInt32(manueldist.Text);
                x = x - distint;       

                if (x < -20000)
                {
                    x = x + distint;
                    SystemSounds.Exclamation.Play();
                    MessageBox.Show("X Ekseni İçin Fazla Değer Girdiniz!", "Hata");
                }
                else
                {
                    distance = manueldist.Text.ToString();
                    SerialPort.Write($"1,{distance},2,0,0,0");
                }
            }
            
        }

        private void rightbutton_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(manueldist.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir mesafe belirleyiniz!", "Hata");
            }
            else
            {
                int distint = Convert.ToInt32(manueldist.Text);
                y = y + distint;
                if (y > 20000)
                {
                    y = y - distint;
                    SystemSounds.Exclamation.Play();
                    MessageBox.Show("Y Ekseni İçin Fazla Değer Girdiniz!", "Hata");
                }
                else
                {
                    distance = manueldist.Text.ToString();       // Mesafe değeri
                    SerialPort.Write($"1,{distance},6,0,0,0");
                }
            }
            
        }

        private void leftbutton_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(manueldist.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir mesafe belirleyiniz!", "Hata");
            }
            else
            {
                int distint = Convert.ToInt32(manueldist.Text);
                y = y - distint;
                if (y < -20000)
                {
                    y = y + distint;
                    SystemSounds.Exclamation.Play();
                    MessageBox.Show("Y Ekseni İçin Fazla Değer Girdiniz!", "Hata");
                }
                else
                {
                    distance = manueldist.Text.ToString();       // Mesafe değeri
                    SerialPort.Write($"1,{distance},4,0,0,0");
                }
            }
            
        }

        private void cambutton_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(comboBox1.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir seri port seçin!", "Hata");
            }
            else
            {
                if (i == 0)
                {
                    SerialPort.Write($"2,0,0,0,0,0");
                    label12.ForeColor = SystemColors.ControlText;
                    label12.Text = "Camera On";
                    i = 1;
                }
                else if (i == 1)
                {
                    SerialPort.Write($"3,0,0,0,0,0");
                    label12.ForeColor = SystemColors.ControlText;
                    label12.Text = "Camera Off";
                    i = 0;
                }
            }
        }



        private void repeatbox_TextChanged(object sender, EventArgs e)
        {
            
        }



        private void home_button_Click(object sender, EventArgs e)
        {

            if (string.IsNullOrEmpty(comboBox1.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir seri port seçin!", "Hata");
            }
            else
            {
                string x_home;
                string y_home;
                if(x == 0 && y == 0)
                {
                    SystemSounds.Exclamation.Play();
                    MessageBox.Show("Tabla Orta Noktada!", "Uyarı!");
                }
                else
                {
                    if (x >= 0 && y >= 0)
                    {
                        x_home = x.ToString();
                        y_home = y.ToString();
                        SerialPort.Write($"6,1,{x_home},{y_home},0,0");
                        x = 0;
                        y = 0;
                    }
                    else if (x <= 0 && y >= 0)
                    {
                        x = Math.Abs(x);
                        y = Math.Abs(y);
                        x_home = x.ToString();
                        y_home = y.ToString();
                        SerialPort.Write($"6,2,{x_home},{y_home},0,0");
                        x = 0;
                        y = 0;
                    
                    }
                    else if (x >= 0 && y <= 0)
                    {
                        x = Math.Abs(x);
                        y = Math.Abs(y);
                        x_home = x.ToString();
                        y_home = y.ToString();
                        SerialPort.Write($"6,4,{x_home},{y_home},0,0");
                        x = 0;
                        y = 0;
                    }
                    else if (x <= 0 && y <= 0)
                    {
                        x = Math.Abs(x);
                        y = Math.Abs(y);
                        x_home = x.ToString();
                        y_home = y.ToString();
                        SerialPort.Write($"6,3,{x_home},{y_home},0,0");
                        x = 0;
                        y = 0;
                    }
                }
            }
            
            
            
        }

        private void button1_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(comboBox1.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir seri port seçin!", "Hata");
            }
            else
            {
                if (stop_but == 0)
                {   
                    button1.Text = "Continue";
                    button1.BackColor = Color.ForestGreen;
                    stop_but = 1;
                    SerialPort.Write($"10");
                }
                else if (stop_but == 1)
                {
                    button1.Text = "Stop";
                    button1.BackColor = Color.Red;
                    stop_but = 0;
                    SerialPort.Write($"11,0,0,0,0,0");
                }
            }
           

        }

        private void button2_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(comboBox1.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir seri port seçin!", "Hata");
            }
            else
            {
                SerialPort.Write($"12");
            }
                
        }

        private void label9_Click(object sender, EventArgs e)
        {

        }

        private void Switch_homing_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(comboBox1.Text))
            {
                SystemSounds.Exclamation.Play();
                MessageBox.Show("Lütfen bir seri port seçin!", "Hata");
            }
            else
            {
                SerialPort.Write($"7,0,0,0,0,0");
                x = 0;
                y = 0;
            }
                
        }
    }
}