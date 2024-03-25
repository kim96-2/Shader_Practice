using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Monster
{
    public Monster(float atk = 10f)
    {
        hp = 100f;
        this.atk = atk;
    }

    public virtual void Move()
    {
        Debug.Log("Monster Move");
    }

    protected void Move(int dir)
    {
        Debug.Log("Monster Move " + dir);
    }

    public void Change(Monster monster)
    {
        monster.atk += 10f;
    }

    protected float hp;

    private float atk;

    public float Atk
    {
        get { return atk; }
        private set { atk = value; }
    }

    public float Atk2 { get => atk; set => atk = value; }

    public float Atk3 { get; private set; }

    public float GetAtk()
    {
        return atk;
    }

    public void SetAtk(float atk)
    {
        this.atk = atk;
    }
}

public interface Animal
{
    void Go();
}

public class Rabbit : Monster , Animal
{
    public Rabbit(float atk = 10f) : base(atk)
    {
        hp = 50f;
    }

    const int NAME = 3;

    private int _name;
    protected int name;
    public int Name2;

    public override void Move()
    {
        base.Move();    
        
        Debug.Log("Rabbit Move");
    }

    public void Go()
    {
        hp = 10;
    }

    int def;
}


public class Test : MonoBehaviour
{
    void change(int num)
    {
        num = 4;
    }


    // Start is called before the first frame update
    void Start()
    {
        Monster monster = new Monster();

        monster.Move();

        Monster monster2 = new Rabbit();

        Debug.Log(monster2.GetAtk());

        monster.Change(monster2);

        Debug.Log(monster2.Atk);

        Debug.Log(monster2.Atk);

        monster2.Move();

    }
}
